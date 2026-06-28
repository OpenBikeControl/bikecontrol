#include "capture_recorder.h"

#include <windows.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Graphics.Capture.h>
#include <winrt/Windows.Graphics.DirectX.h>
#include <winrt/Windows.Graphics.DirectX.Direct3D11.h>
#include <windows.graphics.capture.interop.h>
#include <windows.graphics.directx.direct3d11.interop.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <shlobj.h>
#include <atomic>
#include <chrono>
#include <string>

#pragma comment(lib, "windowsapp")

using namespace winrt;
using namespace winrt::Windows::Graphics::Capture;
using namespace winrt::Windows::Graphics::DirectX;
using namespace winrt::Windows::Graphics::DirectX::Direct3D11;

namespace screen_recorder {

namespace {
std::wstring VideosDir() {
  PWSTR path = nullptr;
  std::wstring dir;
  if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_Videos, 0, nullptr, &path))) {
    dir = path;
    CoTaskMemFree(path);
  }
  dir += L"\\BikeControl";
  CreateDirectoryW(dir.c_str(), nullptr);
  return dir;
}
}  // namespace

struct CaptureRecorder::Impl {
  com_ptr<ID3D11Device> d3dDevice;
  com_ptr<ID3D11DeviceContext> d3dContext;
  IDirect3DDevice winrtDevice{nullptr};
  GraphicsCaptureItem item{nullptr};
  Direct3D11CaptureFramePool framePool{nullptr};
  GraphicsCaptureSession session{nullptr};
  Direct3D11CaptureFramePool::FrameArrived_revoker frameArrived;

  com_ptr<IMFSinkWriter> sinkWriter;
  DWORD streamIndex = 0;
  std::atomic<bool> running{false};
  LONGLONG startQpc = 0;
  LARGE_INTEGER qpcFrequency{};
  UINT width = 0, height = 0;
  std::wstring outPath;

  // Staging texture reused across frames (recreated if size changes).
  com_ptr<ID3D11Texture2D> stagingTexture;
};

bool CaptureRecorder::IsSupported() {
  try {
    return GraphicsCaptureSession::IsSupported();
  } catch (...) { return false; }
}

bool CaptureRecorder::Start() {
  try {
    impl_ = new Impl();

    // 1) D3D11 device with BGRA support (required by WGC).
    D3D_FEATURE_LEVEL fl;
    if (FAILED(D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
            D3D11_CREATE_DEVICE_BGRA_SUPPORT, nullptr, 0, D3D11_SDK_VERSION,
            impl_->d3dDevice.put(), &fl, impl_->d3dContext.put()))) {
      return false;
    }
    com_ptr<IDXGIDevice> dxgiDevice = impl_->d3dDevice.as<IDXGIDevice>();
    com_ptr<::IInspectable> inspectable;
    // VERIFY on Windows: CreateDirect3D11DeviceFromDXGIDevice is in
    // <windows.graphics.directx.direct3d11.interop.h> and links via windowsapp.
    CreateDirect3D11DeviceFromDXGIDevice(dxgiDevice.get(), inspectable.put());
    impl_->winrtDevice = inspectable.as<IDirect3DDevice>();

    // 2) Capture item for the primary monitor.
    HMONITOR mon = MonitorFromWindow(GetDesktopWindow(), MONITOR_DEFAULTTOPRIMARY);
    auto interop = get_activation_factory<GraphicsCaptureItem, IGraphicsCaptureItemInterop>();
    check_hresult(interop->CreateForMonitor(mon,
        guid_of<GraphicsCaptureItem>(), put_abi(impl_->item)));
    auto size = impl_->item.Size();
    impl_->width = static_cast<UINT>(size.Width);
    impl_->height = static_cast<UINT>(size.Height);

    // 3) Media Foundation sink writer (H.264 mp4).
    MFStartup(MF_VERSION);
    impl_->outPath = VideosDir() + L"\\BikeControl_" +
        std::to_wstring(std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::system_clock::now().time_since_epoch()).count()) + L".mp4";
    com_ptr<IMFSinkWriter> writer;
    check_hresult(MFCreateSinkWriterFromURL(impl_->outPath.c_str(), nullptr, nullptr, writer.put()));

    // Output type: H.264
    com_ptr<IMFMediaType> outType;
    MFCreateMediaType(outType.put());
    outType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    outType->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_H264);
    outType->SetUINT32(MF_MT_AVG_BITRATE, 8000000);
    outType->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);
    MFSetAttributeSize(outType.get(), MF_MT_FRAME_SIZE, impl_->width, impl_->height);
    MFSetAttributeRatio(outType.get(), MF_MT_FRAME_RATE, 30, 1);
    MFSetAttributeRatio(outType.get(), MF_MT_PIXEL_ASPECT_RATIO, 1, 1);
    writer->AddStream(outType.get(), &impl_->streamIndex);

    // Input type: RGB32 (= BGRA from WGC; MF treats RGB32 as BGRA on Windows).
    com_ptr<IMFMediaType> inType;
    MFCreateMediaType(inType.put());
    inType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    inType->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);  // BGRA from WGC
    inType->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);
    MFSetAttributeSize(inType.get(), MF_MT_FRAME_SIZE, impl_->width, impl_->height);
    MFSetAttributeRatio(inType.get(), MF_MT_FRAME_RATE, 30, 1);
    // VERIFY on Windows: MF_MT_DEFAULT_STRIDE for top-down RGB32 is positive
    // (width * 4).  WGC surfaces are top-down, so this is correct.
    // VERIFY on Windows: Some H.264 encoders require even dimensions; ensure
    // width/height are even (round down if needed).
    MFSetAttributeSize(inType.get(), MF_MT_FRAME_SIZE, impl_->width, impl_->height);
    writer->SetInputMediaType(impl_->streamIndex, inType.get(), nullptr);
    writer->BeginWriting();
    impl_->sinkWriter = writer;

    // Record the QPC start time and frequency for sample timestamps.
    QueryPerformanceFrequency(&impl_->qpcFrequency);
    QueryPerformanceCounter(reinterpret_cast<LARGE_INTEGER*>(&impl_->startQpc));

    // 4) Frame pool + session.
    impl_->framePool = Direct3D11CaptureFramePool::Create(
        impl_->winrtDevice, DirectXPixelFormat::B8G8R8A8UIntNormalized, 2, impl_->item.Size());
    impl_->session = impl_->framePool.CreateCaptureSession(impl_->item);
    impl_->running = true;

    // -----------------------------------------------------------------------
    // FrameArrived: D3D texture → staging copy → CPU map → IMFSample → write
    //
    // NOTE: This is the part most likely to need iteration on-device.
    // The overall flow is correct per MSDN; exact error codes and any
    // quirks of the H.264 encoder (stride alignment, colorspace hints)
    // may need adjustment. See VERIFY comments inline.
    // -----------------------------------------------------------------------
    impl_->frameArrived = impl_->framePool.FrameArrived(auto_revoke,
      [this](Direct3D11CaptureFramePool const& pool, auto const&) {
        auto frame = pool.TryGetNextFrame();
        if (!frame || !impl_->running) return;

        // --- Step A: Get the ID3D11Texture2D from the WGC frame surface ---
        //
        // frame.Surface() is an IDirect3DSurface (WinRT). To get the
        // underlying D3D11 texture, QI for IDirect3DDxgiInterfaceAccess.
        // VERIFY on Windows: IDirect3DDxgiInterfaceAccess is in
        // <windows.graphics.directx.direct3d11.interop.h>.
        auto surface = frame.Surface();
        com_ptr<ID3D11Texture2D> frameTexture;
        {
          // IDirect3DDxgiInterfaceAccess lives in the ABI namespace
          // ::Windows::Graphics::DirectX::Direct3D11 (declared by
          // <windows.graphics.directx.direct3d11.interop.h>), NOT the winrt
          // projection namespace brought in by `using namespace` above. It must
          // be fully qualified with a leading :: so `using namespace winrt;`
          // doesn't misroute it to a non-existent winrt::Windows::... type.
          auto dxgiAccess = surface.as<
              ::Windows::Graphics::DirectX::Direct3D11::IDirect3DDxgiInterfaceAccess>();
          HRESULT hr = dxgiAccess->GetInterface(IID_PPV_ARGS(frameTexture.put()));
          if (FAILED(hr)) return;
        }

        // --- Step B: Describe the source texture and create/reuse a staging texture ---
        D3D11_TEXTURE2D_DESC srcDesc{};
        frameTexture->GetDesc(&srcDesc);

        // Reuse staging texture if dimensions match; otherwise (re)create.
        bool needNewStaging = true;
        if (impl_->stagingTexture) {
          D3D11_TEXTURE2D_DESC stgDesc{};
          impl_->stagingTexture->GetDesc(&stgDesc);
          needNewStaging = (stgDesc.Width != srcDesc.Width ||
                            stgDesc.Height != srcDesc.Height);
        }
        if (needNewStaging) {
          impl_->stagingTexture = nullptr;
          D3D11_TEXTURE2D_DESC stgDesc{};
          stgDesc.Width = srcDesc.Width;
          stgDesc.Height = srcDesc.Height;
          stgDesc.MipLevels = 1;
          stgDesc.ArraySize = 1;
          stgDesc.Format = srcDesc.Format;  // DXGI_FORMAT_B8G8R8A8_UNORM
          stgDesc.SampleDesc.Count = 1;
          stgDesc.SampleDesc.Quality = 0;
          stgDesc.Usage = D3D11_USAGE_STAGING;
          stgDesc.BindFlags = 0;
          stgDesc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
          stgDesc.MiscFlags = 0;
          HRESULT hr = impl_->d3dDevice->CreateTexture2D(
              &stgDesc, nullptr, impl_->stagingTexture.put());
          if (FAILED(hr)) return;
        }

        // --- Step C: CopyResource GPU→staging ---
        impl_->d3dContext->CopyResource(impl_->stagingTexture.get(), frameTexture.get());

        // --- Step D: Map the staging texture for CPU read ---
        D3D11_MAPPED_SUBRESOURCE mapped{};
        HRESULT hrMap = impl_->d3dContext->Map(
            impl_->stagingTexture.get(), 0, D3D11_MAP_READ, 0, &mapped);
        if (FAILED(hrMap)) return;

        // --- Step E: Build IMFSample from the BGRA bytes ---
        const UINT frameWidth = srcDesc.Width;
        const UINT frameHeight = srcDesc.Height;
        // BGRA: 4 bytes per pixel, top-down (positive stride = width*4 contiguous).
        const DWORD bytesPerRow = frameWidth * 4;
        const DWORD totalBytes = bytesPerRow * frameHeight;

        com_ptr<IMFMediaBuffer> mfBuffer;
        HRESULT hr = MFCreateMemoryBuffer(totalBytes, mfBuffer.put());
        if (FAILED(hr)) {
          impl_->d3dContext->Unmap(impl_->stagingTexture.get(), 0);
          return;
        }

        BYTE* pDst = nullptr;
        DWORD maxLen = 0, curLen = 0;
        hr = mfBuffer->Lock(&pDst, &maxLen, &curLen);
        if (FAILED(hr)) {
          impl_->d3dContext->Unmap(impl_->stagingTexture.get(), 0);
          return;
        }

        // Copy row-by-row in case the GPU stride (RowPitch) > bytesPerRow.
        //
        // Orientation: WGC/D3D surfaces are top-down (row 0 = top), but the MF
        // SinkWriter's RGB->NV12 conversion treats uncompressed RGB32 as
        // bottom-up (legacy DIB convention) when no stride sign says otherwise.
        // Feeding our top-down buffer straight through produced an upside-down
        // recording. We cancel that fixed vertical flip by writing each source
        // row into the mirrored destination row, i.e. handing MF a bottom-up
        // buffer. Same number of memcpys, so no extra cost.
        const BYTE* pSrc = static_cast<const BYTE*>(mapped.pData);
        for (UINT row = 0; row < frameHeight; ++row) {
          memcpy(pDst + (frameHeight - 1 - row) * bytesPerRow,
                 pSrc + row * mapped.RowPitch,
                 bytesPerRow);
        }
        mfBuffer->Unlock();
        mfBuffer->SetCurrentLength(totalBytes);

        impl_->d3dContext->Unmap(impl_->stagingTexture.get(), 0);

        // --- Step F: Create the IMFSample, set time and duration, write ---
        com_ptr<IMFSample> sample;
        hr = MFCreateSample(sample.put());
        if (FAILED(hr)) return;

        sample->AddBuffer(mfBuffer.get());

        // Compute sample time in 100ns units from QPC.
        LARGE_INTEGER nowQpc{};
        QueryPerformanceCounter(&nowQpc);
        LONGLONG elapsedQpc = nowQpc.QuadPart - impl_->startQpc;
        // Convert QPC ticks → 100ns units: (ticks * 10,000,000) / freq
        // VERIFY on Windows: integer overflow possible for very long recordings;
        // use MFllMulDiv if available, or promote to __int128 / use double.
        LONGLONG sampleTime = (elapsedQpc * 10000000LL) / impl_->qpcFrequency.QuadPart;
        // Duration for 30 fps = 1/30 s = 333333 100ns units.
        LONGLONG sampleDuration = 333333LL;

        sample->SetSampleTime(sampleTime);
        sample->SetSampleDuration(sampleDuration);

        // VERIFY on Windows: WriteSample must be called from the same thread
        // that called BeginWriting (or from any thread if the writer was created
        // with MF_SINK_WRITER_ASYNC_CALLBACK). Here we call it inline from the
        // WGC dispatcher thread; this is typically fine for the synchronous writer.
        if (impl_->sinkWriter && impl_->running) {
          impl_->sinkWriter->WriteSample(impl_->streamIndex, sample.get());
        }
      });

    impl_->session.StartCapture();
    return true;
  } catch (...) {
    return false;
  }
}

std::string CaptureRecorder::Stop() {
  if (!impl_) return "";
  impl_->running = false;
  try {
    impl_->frameArrived.revoke();
    if (impl_->session) impl_->session.Close();
    if (impl_->framePool) impl_->framePool.Close();
    impl_->stagingTexture = nullptr;
    if (impl_->sinkWriter) impl_->sinkWriter->Finalize();
    MFShutdown();
  } catch (...) {}
  std::wstring w = impl_->outPath;
  delete impl_; impl_ = nullptr;
  int len = WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, nullptr, 0, nullptr, nullptr);
  std::string out(len > 0 ? len - 1 : 0, '\0');
  if (len > 0) WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, out.data(), len, nullptr, nullptr);
  return out;
}

CaptureRecorder::~CaptureRecorder() { if (impl_) { Stop(); } }
}  // namespace screen_recorder
