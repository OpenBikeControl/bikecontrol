#pragma once

#include <windows.h>
#include <tchar.h>

namespace universal_ble
{
    typedef struct SizeAndPos_s
    {
        int x, y, width, height;
    } SizeAndPos_t;

    const WORD ID_btnOK = 1;
    const WORD ID_txtEdit = 4;
    HWND txtEditHandle = NULL;
    TCHAR textBoxText[16];

    // Positions and dimensions of UI elements: X, Y, Width, Height
    const SizeAndPos_t mainWindow = {150, 150, 450, 260};
    const SizeAndPos_t txtEdit = {50, 40, 320, 40};
    const SizeAndPos_t btnOK = {50, 100, 320, 40};

    LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
    {
        switch (msg)
        {
        case WM_CREATE:
        {
            txtEditHandle = CreateWindow(
                TEXT("Edit"), TEXT(""),
                WS_CHILD | WS_VISIBLE | WS_BORDER | ES_NUMBER,
                txtEdit.x, txtEdit.y, txtEdit.width, txtEdit.height,
                hwnd, (HMENU)ID_txtEdit, NULL, NULL);
            CreateWindow(
                TEXT("Button"), TEXT("OK"),
                WS_CHILD | WS_VISIBLE | BS_FLAT,
                btnOK.x, btnOK.y, btnOK.width, btnOK.height,
                hwnd, (HMENU)ID_btnOK, NULL, NULL);
            break;
        }
        case WM_COMMAND:
            if (LOWORD(wParam) == ID_btnOK)
            {
                GetWindowText(txtEditHandle, textBoxText, sizeof(textBoxText) / sizeof(TCHAR));
                DestroyWindow(hwnd);
            }
            break;
        case WM_CLOSE:
            DestroyWindow(hwnd);
            break;
        case WM_DESTROY:
            PostQuitMessage(0);
            break;
        default:
            return DefWindowProc(hwnd, msg, wParam, lParam);
        }

        return 0;
    }

    hstring askForPairingPin()
    {
        textBoxText[0] = '\0';
        HINSTANCE hInstance = GetModuleHandle(NULL);
        MSG msg;
        WNDCLASS mainWindowClass = {0};
        mainWindowClass.lpszClassName = TEXT("JRH.MainWindow");
        mainWindowClass.hInstance = hInstance;
        mainWindowClass.hbrBackground = GetSysColorBrush(COLOR_BTNHIGHLIGHT);
        mainWindowClass.lpfnWndProc = WndProc;
        mainWindowClass.hCursor = LoadCursor(0, IDC_ARROW);

        // Register the window class
        if (!RegisterClass(&mainWindowClass))
        {
            std::cout << "PinPairDialog: Failed to register window class" << std::endl;
            return L"";
        }

        HWND hwnd = CreateWindow(
            mainWindowClass.lpszClassName,
            TEXT("PIN"), (WS_OVERLAPPEDWINDOW & ~WS_THICKFRAME & ~WS_MINIMIZEBOX & ~WS_MAXIMIZEBOX) | WS_VISIBLE,
            mainWindow.x, mainWindow.y, mainWindow.width, mainWindow.height,
            NULL, 0, hInstance, NULL);

        if (hwnd == NULL)
        {
            std::cout << "PinPairDialog: Failed to create window" << std::endl;
            return L"";
        }

        // After creating the window, make it topmost
        SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);

        ShowWindow(hwnd, SW_SHOW);

        // Create a font with the desired size
        HFONT hFont = CreateFont(
            36,                       // Height of the font
            0,                        // Width of the font
            0,                        // Angle of escapement
            0,                        // Orientation angle
            FW_NORMAL,                // Font weight
            FALSE,                    // Italic attribute option
            FALSE,                    // Underline attribute option
            FALSE,                    // Strikeout attribute option
            DEFAULT_CHARSET,          // Character set identifier
            OUT_DEFAULT_PRECIS,       // Output precision
            CLIP_DEFAULT_PRECIS,      // Clipping precision
            DEFAULT_QUALITY,          // Output quality
            DEFAULT_PITCH | FF_SWISS, // Pitch and family
            TEXT("Arial")             // Font name
        );

        // Set the font to the edit control
        SendMessage(txtEditHandle, WM_SETFONT, (WPARAM)hFont, TRUE);

        while (GetMessage(&msg, NULL, 0, 0))
        {
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        }

        if (msg.wParam != 0)
        {
            std::wcout << "PinPairDialog: Got invalid result" << std::endl;
        }

        DeleteObject(hFont);
        DestroyWindow(hwnd);
        UnregisterClass(mainWindowClass.lpszClassName, hInstance);
        return winrt::to_hstring(textBoxText);
    }
}
