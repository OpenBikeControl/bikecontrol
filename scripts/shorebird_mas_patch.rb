#!/usr/bin/env ruby
# frozen_string_literal: true

# Vendored from https://gist.github.com/lukemmtt/d52a729010f30c74d004ecd169805dca
# Workaround for shorebirdtech/shorebird#3223 (Mac App Store binary mismatch).
# See scripts/README-shorebird-macos.md for the BikeControl-specific setup.
# Only the APP_NAME / APP_BUNDLE_ID defaults below were changed from upstream so
# future upstream updates stay easy to diff.

require "base64"
require "digest"
require "fileutils"
require "json"
require "net/http"
require "open3"
require "openssl"
require "rubygems"
require "shellwords"
require "time"
require "yaml"

APP_NAME = ENV.fetch("APP_NAME", "BikeControl")
APP_BUNDLE_ID = ENV.fetch("APP_BUNDLE_ID", "de.jonasbark.swiftPlay")
ASC_APP_ID = ENV.fetch("ASC_APP_ID", "1234567890")
ASC_KEY_ID = ENV.fetch("ASC_KEY_ID", "ABCDEFGHIJ")
ASC_ISSUER_ID = ENV.fetch("ASC_ISSUER_ID", "00000000-0000-0000-0000-000000000000")
ASC_API_KEY_PATH = File.expand_path(ENV.fetch("ASC_API_KEY_PATH", "~/.private_keys/AuthKey_#{ASC_KEY_ID}.p8"))
MACOS_APP_PATH = File.expand_path(ENV.fetch("MACOS_APP_PATH", "/Applications/#{APP_NAME}.app"))
MAS_ARTIFACT_ARCH = ENV["SHOREBIRD_MACOS_RELEASE_ARTIFACT_ARCH"] || ENV["MAS_ARTIFACT_ARCH"] || "app_mas_contents"
SHOREBIRD_BIN = ENV["SHOREBIRD_BIN"].to_s.empty? ? "shorebird" : ENV["SHOREBIRD_BIN"]
SHOREBIRD_YAML_PATH = File.expand_path(ENV.fetch("SHOREBIRD_YAML_PATH", "shorebird.yaml"))
PATCHER_PATH = File.expand_path(ENV.fetch("SHOREBIRD_MACOS_PATCHER_PATH", "~/.shorebird/packages/shorebird_cli/lib/src/commands/patch/macos_patcher.dart"))
PATCH_ARGS = ENV.fetch("SHOREBIRD_PATCH_ARGS", "--allow-asset-diffs --min-link-percentage=90")
INSTALL_TIMEOUT_SECONDS = Integer(ENV.fetch("MAS_INSTALL_TIMEOUT_SECONDS", "300"))

def say(message)
  warn(message)
end

def die(message)
  abort("error: #{message}")
end

def run(*args, env: {}, allow_failure: false)
  args = args.flatten
  say("$ #{args.shelljoin}")
  ok = system(env, *args)
  die("command failed: #{args.shelljoin}") if !ok && !allow_failure
  ok
end

def capture(*args, env: {}, allow_failure: false)
  args = args.flatten
  stdout, stderr, status = Open3.capture3(env, *args)
  die("command failed: #{args.shelljoin}\n#{stdout}#{stderr}") if !status.success? && !allow_failure
  stdout
end

def shell_capture(command, allow_failure: false)
  stdout, stderr, status = Open3.capture3("sh", "-lc", command)
  die("command failed: #{command}\n#{stdout}#{stderr}") if !status.success? && !allow_failure
  stdout
end

def b64url(bytes)
  Base64.urlsafe_encode64(bytes).delete("=")
end

def asn1_ecdsa_to_raw(signature_der)
  sequence = OpenSSL::ASN1.decode(signature_der)
  r = sequence.value[0].value.to_s(2).rjust(32, "\0")[-32, 32]
  s = sequence.value[1].value.to_s(2).rjust(32, "\0")[-32, 32]
  r + s
end

def asc_private_key
  key_content = ENV["ASC_API_KEY_CONTENT"] || File.read(ASC_API_KEY_PATH)
  OpenSSL::PKey.read(key_content)
rescue Errno::ENOENT
  die("App Store Connect key not found at #{ASC_API_KEY_PATH}. Set ASC_API_KEY_PATH or ASC_API_KEY_CONTENT.")
end

def asc_jwt
  now = Time.now.to_i
  header = { alg: "ES256", kid: ASC_KEY_ID, typ: "JWT" }
  payload = { iss: ASC_ISSUER_ID, iat: now, exp: now + 20 * 60, aud: "appstoreconnect-v1" }
  signing_input = "#{b64url(header.to_json)}.#{b64url(payload.to_json)}"
  digest = OpenSSL::Digest::SHA256.digest(signing_input)
  signature_der = asc_private_key.dsa_sign_asn1(digest)
  "#{signing_input}.#{b64url(asn1_ecdsa_to_raw(signature_der))}"
end

def asc_get(path, query = {})
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  uri.query = URI.encode_www_form(query) unless query.empty?
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{asc_jwt}"
    http.request(req)
  end
  die("App Store Connect GET #{path} failed (HTTP #{response.code}): #{response.body}") unless response.code.to_i < 300
  JSON.parse(response.body)
end

def build_map(body)
  (body["included"] || [])
    .select { |record| record["type"] == "builds" }
    .each_with_object({}) { |build, map| map[build["id"]] = build }
end

def latest_ready_for_sale_release_version
  body = asc_get(
    "/v1/apps/#{ASC_APP_ID}/appStoreVersions",
    "filter[platform]" => "MAC_OS",
    "include" => "build",
    "fields[builds]" => "version",
    "limit" => "50"
  )
  builds = build_map(body)
  ready_versions = (body["data"] || []).select { |version| version.dig("attributes", "appStoreState") == "READY_FOR_SALE" }
  die("No READY_FOR_SALE Mac App Store version found for ASC app #{ASC_APP_ID}.") if ready_versions.empty?

  best = ready_versions.max_by do |version_record|
    version = version_record.dig("attributes", "versionString").to_s
    build_id = version_record.dig("relationships", "build", "data", "id")
    build_number = builds.dig(build_id, "attributes", "version").to_i
    [Gem::Version.new(version), build_number]
  end

  build_id = best.dig("relationships", "build", "data", "id")
  build_number = builds.dig(build_id, "attributes", "version")
  die("READY_FOR_SALE version #{best.dig("attributes", "versionString")} has no attached build.") if build_number.to_s.empty?

  release_version = "#{best.dig("attributes", "versionString")}+#{build_number}"
  say("Mac App Store READY_FOR_SALE release: #{release_version}")
  release_version
end

def release_version
  value = ENV["RELEASE_VERSION"].to_s.strip
  return value unless value.empty?

  latest_ready_for_sale_release_version
end

def parse_release_version!(value)
  version, build_number = value.to_s.strip.split("+", 2)
  die("Release version must look like x.y.z+build, got #{value.inspect}") if version.to_s.empty? || build_number.to_s.empty?
  [version, build_number]
end

# App Store Connect keeps the marketing version exactly as it was typed there ("6.6"),
# while Flutter, Shorebird and the built app bundle all use the three-part pubspec
# version ("6.6.0"). Compare the two spellings semantically instead of by string.
def semantic_version(value)
  Gem::Version.new(value.to_s.strip)
rescue ArgumentError
  nil
end

def same_version?(left, right)
  left_version = semantic_version(left)
  right_version = semantic_version(right)
  return left.to_s.strip == right.to_s.strip if left_version.nil? || right_version.nil?

  left_version == right_version
end

def same_release_version?(left, right)
  left_version, left_build = left.to_s.strip.split("+", 2)
  right_version, right_build = right.to_s.strip.split("+", 2)
  left_build.to_s == right_build.to_s && same_version?(left_version, right_version)
end

def shorebird_app_id
  YAML.load_file(SHOREBIRD_YAML_PATH).fetch("app_id")
rescue Errno::ENOENT
  die("Could not find shorebird.yaml at #{SHOREBIRD_YAML_PATH}. Run from your Flutter app root or set SHOREBIRD_YAML_PATH.")
end

def shorebird_google_oauth_client
  # These are Shorebird CLI's native-app OAuth client values, not user credentials.
  # Read them from the installed CLI instead of copying the literals into this script.
  auth_path = File.expand_path("~/.shorebird/packages/shorebird_cli/lib/src/auth/auth.dart")
  source = File.exist?(auth_path) ? File.read(auth_path) : ""
  google_block = source[/case AuthProvider\.google:.*?case AuthProvider\.microsoft:/m]
  values = google_block.to_s.scan(/['"]{1,3}([^'"\n]+(?:apps\.googleusercontent\.com|GOCSPX-[^'"\n]+))['"]{1,3}/).flatten
  client_id = values.find { |value| value.end_with?(".apps.googleusercontent.com") }
  client_secret = values.find { |value| value.start_with?("GOCSPX-") }
  die("Could not find Shorebird CLI Google OAuth client values in #{auth_path}. Run `shorebird login`, or set a fresh local credentials.json token.") if client_id.to_s.empty? || client_secret.to_s.empty?
  [client_id, client_secret]
end

def shorebird_api_token
  env_token = ENV["SHOREBIRD_TOKEN"].to_s.strip
  unless env_token.empty?
    # Console API keys (sb_api_...) are already bearer tokens; only the legacy
    # `shorebird login:ci` blob needs the base64 + OAuth refresh dance.
    return env_token if env_token.start_with?("sb_api_")

    ci_token = JSON.parse(Base64.decode64(env_token))
    die("Unsupported Shorebird auth provider: #{ci_token["auth_provider"]}") unless ci_token["auth_provider"] == "google"
    client_id, client_secret = shorebird_google_oauth_client

    uri = URI("https://oauth2.googleapis.com/token")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      req = Net::HTTP::Post.new(uri)
      req.set_form_data(
        "client_id" => client_id,
        "client_secret" => client_secret,
        "refresh_token" => ci_token.fetch("refresh_token"),
        "grant_type" => "refresh_token"
      )
      http.request(req)
    end
    die("Google OAuth refresh failed (HTTP #{response.code}): #{response.body}") unless response.code == "200"
    return JSON.parse(response.body).fetch("id_token")
  end

  credentials_path = File.expand_path("~/Library/Application Support/shorebird/credentials.json")
  return JSON.parse(File.read(credentials_path)).fetch("idToken") if File.exist?(credentials_path)

  die("No Shorebird auth available. Set SHOREBIRD_TOKEN or run `shorebird login`.")
end

def shorebird_api(method_class, path, query: nil, body: nil)
  uri = URI("https://api.shorebird.dev#{path}")
  uri.query = URI.encode_www_form(query) if query && !query.empty?
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    req = method_class.new(uri)
    req["Authorization"] = "Bearer #{shorebird_api_token}"
    req["x-version"] = "0.9.0+1"
    if body
      req["Content-Type"] = "application/json"
      req.body = body.to_json
    end
    http.request(req)
  end
  parsed = JSON.parse(response.body.empty? ? "{}" : response.body)
  die("Shorebird API unauthorized. Check SHOREBIRD_TOKEN or run `shorebird login`.") if parsed["code"] == "user_unauthorized"
  die("Shorebird API #{method_class} #{path} failed (HTTP #{response.code}): #{response.body}") unless response.code.to_i < 300
  parsed
end

def shorebird_release_for_version(value)
  body = shorebird_api(Net::HTTP::Get, "/api/v1/apps/#{shorebird_app_id}/releases")
  releases = body["releases"] || []
  release = releases.find { |record| record["version"] == value } ||
            releases.find { |record| same_release_version?(record["version"], value) }
  die("No Shorebird release found for #{value}. Run `shorebird release macos` for this version before registering the MAS baseline.") unless release
  release
end

# Shorebird's spelling of the version is the one the installed app bundle and
# `shorebird patch` agree on, so everything downstream uses it rather than the
# App Store Connect string.
def resolve_release_version!(value)
  release = shorebird_release_for_version(value)
  resolved = release["version"].to_s
  say("App Store version #{value} maps to Shorebird release #{resolved}.") unless resolved == value
  [release, resolved]
end

def shorebird_release_artifacts(release_id:, arch:, platform:)
  body = shorebird_api(
    Net::HTTP::Get,
    "/api/v1/apps/#{shorebird_app_id}/releases/#{release_id}/artifacts",
    query: { "arch" => arch, "platform" => platform }
  )
  body["artifacts"] || []
end

def ensure_shorebird_release_artifact!(value)
  release, resolved = resolve_release_version!(value)
  artifacts = shorebird_release_artifacts(release_id: release.fetch("id"), arch: MAS_ARTIFACT_ARCH, platform: "macos")
  die("Shorebird release #{resolved} has no macos/#{MAS_ARTIFACT_ARCH} artifact. Run `ruby #{$PROGRAM_NAME} register-baseline` first.") if artifacts.empty?
  say("Shorebird release #{resolved} has #{artifacts.size} macos/#{MAS_ARTIFACT_ARCH} artifact(s).")
  resolved
end

def upload_shorebird_release_artifact!(release_id:, artifact_path:, arch:, platform:)
  hash = Digest::SHA256.file(artifact_path).hexdigest
  size = File.size(artifact_path)
  create_command = [
    "curl", "--http1.1", "--retry", "3", "--retry-all-errors", "-sS", "-f", "-X", "POST",
    "-H", "Authorization: Bearer #{shorebird_api_token}",
    "-H", "x-version: 0.9.0+1",
    "-F", "arch=#{arch}",
    "-F", "platform=#{platform}",
    "-F", "hash=#{hash}",
    "-F", "filename=#{File.basename(artifact_path)}",
    "-F", "can_sideload=true",
    "-F", "size=#{size}",
    "https://api.shorebird.dev/api/v1/apps/#{shorebird_app_id}/releases/#{release_id}/artifacts"
  ]

  stdout, stderr, status = Open3.capture3(*create_command)
  die("Shorebird artifact registration failed (exit #{status.exitstatus}): #{stdout}#{stderr}") unless status.success?
  response = JSON.parse(stdout)
  upload_url = response["url"]
  die("Shorebird artifact registration response did not include upload url: #{response}") if upload_url.to_s.empty?

  upload_stdout, upload_stderr, upload_status = Open3.capture3(
    "curl", "--http1.1", "--retry", "3", "--retry-all-errors", "-sS", "-f", "-X", "POST", "-F", "file=@#{artifact_path}", upload_url
  )
  die("Shorebird artifact upload failed (exit #{upload_status.exitstatus}): #{upload_stdout}#{upload_stderr}") unless upload_status.success?
  say("Uploaded Shorebird #{platform}/#{arch} artifact #{File.basename(artifact_path)} (sha256 #{hash})")
  response.merge("local_hash" => hash, "local_size" => size)
end

def plist_value(plist_path, key)
  capture("/usr/libexec/PlistBuddy", "-c", "Print :#{key}", plist_path).strip
end

def macos_app_bundle_info(app_path)
  die("App not installed at #{app_path}. Install it from the Mac App Store or let the script update it.") unless File.directory?(app_path)
  info_plist = File.join(app_path, "Contents", "Info.plist")
  executable_name = plist_value(info_plist, "CFBundleExecutable")
  {
    version: plist_value(info_plist, "CFBundleShortVersionString"),
    build_number: plist_value(info_plist, "CFBundleVersion"),
    executable_name: executable_name,
    app_executable: File.join(app_path, "Contents", "MacOS", executable_name),
    flutter_executable: File.join(app_path, "Contents", "Frameworks", "App.framework", "App")
  }
end

def macos_app_signing_authorities(app_path)
  stdout, stderr, = Open3.capture3("codesign", "-dvvv", app_path)
  (stdout + stderr).lines.filter_map { |line| line.split("Authority=", 2).last&.strip if line.include?("Authority=") }
end

def mas_signed_app_matches?(version:, build_number:)
  info = macos_app_bundle_info(MACOS_APP_PATH) rescue nil
  authorities = File.directory?(MACOS_APP_PATH) ? macos_app_signing_authorities(MACOS_APP_PATH) : []
  info &&
    same_version?(info[:version], version) &&
    info[:build_number] == build_number &&
    authorities.any? { |authority| authority.include?("Apple Mac OS Application Signing") }
end

def install_or_update_mas_app!(version:, build_number:)
  return if mas_signed_app_matches?(version: version, build_number: build_number)

  say("Installed app does not match #{version}+#{build_number}; installing/updating from the Mac App Store.")
  run("osascript", "-e", "tell application id \"#{APP_BUNDLE_ID}\" to quit", allow_failure: true)

  if ENV["MAS_UPDATE_COMMAND"].to_s.strip != ""
    run("sh", "-lc", ENV.fetch("MAS_UPDATE_COMMAND"))
  else
    mas_bin = shell_capture("command -v mas", allow_failure: true).strip
    die("`mas` CLI not found. Install with `brew install mas`, install the live app manually, or set MAS_UPDATE_COMMAND.") if mas_bin.empty?
    run("sudo", mas_bin, "install", "--force", ASC_APP_ID, allow_failure: true)
    run("sudo", mas_bin, "update", "--force", "--verbose", ASC_APP_ID, allow_failure: true)
  end

  deadline = Time.now + INSTALL_TIMEOUT_SECONDS
  until mas_signed_app_matches?(version: version, build_number: build_number)
    die("Timed out waiting for Mac App Store app #{version}+#{build_number} at #{MACOS_APP_PATH}. Install/update it manually and rerun.") if Time.now > deadline
    sleep 5
  end
end

def capture_macos_installed_app_artifact!(value)
  version, build_number = parse_release_version!(value)
  info = macos_app_bundle_info(MACOS_APP_PATH)
  die("Installed app is #{info[:version]}+#{info[:build_number]}, expected #{value}.") unless same_version?(info[:version], version) && info[:build_number] == build_number
  die("Missing Flutter executable at #{info[:flutter_executable]}. The zip must contain Contents/Frameworks/App.framework/App.") unless File.exist?(info[:flutter_executable])
  die("Missing main executable at #{info[:app_executable]}.") unless File.exist?(info[:app_executable])

  run("codesign", "--verify", "--deep", "--strict", MACOS_APP_PATH)
  authorities = macos_app_signing_authorities(MACOS_APP_PATH)
  say("Mac app signing authorities: #{authorities.join(" > ")}")
  die("Installed app is not Mac App Store signed. Expected Apple Mac OS Application Signing authority.") unless authorities.any? { |authority| authority.include?("Apple Mac OS Application Signing") }

  artifact_dir = File.join(ENV["RUNNER_TEMP"] || "/tmp", "shorebird-macos-mas-artifacts")
  FileUtils.mkdir_p(artifact_dir)
  zip_path = File.join(artifact_dir, "#{APP_NAME}-#{value.tr("+", "-")}-mas.app.zip")
  File.delete(zip_path) if File.exist?(zip_path)

  run("ditto", "--norsrc", "-c", "-k", MACOS_APP_PATH, zip_path, env: { "COPYFILE_DISABLE" => "1" })

  {
    path: zip_path,
    sha256: Digest::SHA256.file(zip_path).hexdigest,
    size: File.size(zip_path),
    app_executable_sha256: Digest::SHA256.file(info[:app_executable]).hexdigest,
    flutter_executable_sha256: Digest::SHA256.file(info[:flutter_executable]).hexdigest
  }
end

def invalidate_shorebird_cache!
  stamp_path = File.expand_path("~/.shorebird/bin/cache/shorebird.stamp")
  File.delete(stamp_path) if File.exist?(stamp_path)
end

def with_shorebird_macos_arch_override
  die("Could not find local Shorebird macos_patcher.dart at #{PATCHER_PATH}. Set SHOREBIRD_MACOS_PATCHER_PATH if your Shorebird install is elsewhere.") unless File.exist?(PATCHER_PATH)

  original = File.read(PATCHER_PATH)
  changed = false

  unless original.include?("SHOREBIRD_MACOS_RELEASE_ARTIFACT_ARCH")
    modified = original
      .sub("import 'dart:io';", "import 'dart:io' hide Platform;\nimport 'dart:io' as io show Platform;")
      .sub("String get primaryReleaseArtifactArch => 'app';", "String get primaryReleaseArtifactArch =>\n      io.Platform.environment['SHOREBIRD_MACOS_RELEASE_ARTIFACT_ARCH'] ?? 'app';")

    die("Unable to patch local Shorebird CLI. macos_patcher.dart no longer has the expected import/getter shape.") if modified == original || !modified.include?("SHOREBIRD_MACOS_RELEASE_ARTIFACT_ARCH")
    File.write(PATCHER_PATH, modified)
    changed = true
    invalidate_shorebird_cache!
    run(SHOREBIRD_BIN, "--version")
  end

  yield
ensure
  if defined?(changed) && changed && defined?(original)
    File.write(PATCHER_PATH, original)
    invalidate_shorebird_cache!
  end
end

def register_mas_baseline!
  release, value = resolve_release_version!(release_version)
  version, build_number = parse_release_version!(value)

  install_or_update_mas_app!(version: version, build_number: build_number)
  artifact = capture_macos_installed_app_artifact!(value)

  say("Captured MAS app artifact: #{artifact[:path]}")
  say("  zip sha256: #{artifact[:sha256]}")
  say("  App.framework/App sha256: #{artifact[:flutter_executable_sha256]}")
  say("  main executable sha256: #{artifact[:app_executable_sha256]}")

  existing = shorebird_release_artifacts(release_id: release.fetch("id"), arch: MAS_ARTIFACT_ARCH, platform: "macos")
  if existing.any?
    if existing.any? { |artifact_record| artifact_record["hash"] == artifact[:sha256] }
      say("Shorebird #{value} already has matching macos/#{MAS_ARTIFACT_ARCH} artifact.")
      return
    end

    die("Shorebird #{value} already has a macos/#{MAS_ARTIFACT_ARCH} artifact with a different hash. Re-run register-baseline and patch with MAS_ARTIFACT_ARCH=#{MAS_ARTIFACT_ARCH}_v2.")
  end

  if ENV["DRY_RUN"] == "true"
    say("Dry run complete; MAS artifact captured and validated but not uploaded.")
    return
  end

  upload_shorebird_release_artifact!(
    release_id: release.fetch("id"),
    artifact_path: artifact.fetch(:path),
    arch: MAS_ARTIFACT_ARCH,
    platform: "macos"
  )

  ensure_shorebird_release_artifact!(value)
  say("Registered Mac App Store Shorebird baseline for #{value} as macos/#{MAS_ARTIFACT_ARCH}.")
end

def patch_mas_release!
  value = ensure_shorebird_release_artifact!(release_version)

  patch_args = Shellwords.split(PATCH_ARGS)
  patch_args << "--dry-run" if ENV["DRY_RUN"] == "true" && !patch_args.include?("--dry-run")

  with_shorebird_macos_arch_override do
    run(
      SHOREBIRD_BIN,
      "patch",
      "--platforms=macos",
      "--release-version", value,
      *patch_args,
      env: { "SHOREBIRD_MACOS_RELEASE_ARTIFACT_ARCH" => MAS_ARTIFACT_ARCH }
    )
  end
end

def baseline_status!
  ensure_shorebird_release_artifact!(release_version)
end

def usage!
  script = $PROGRAM_NAME
  warn <<~USAGE
    Usage:
      ruby #{script} register-baseline
      ruby #{script} status
      ruby #{script} patch

    Common environment:
      RELEASE_VERSION=x.y.z+build
      MAS_ARTIFACT_ARCH=app_mas_contents_v2
      DRY_RUN=true
      SHOREBIRD_PATCH_ARGS="--allow-asset-diffs --min-link-percentage=90 --track staging"
  USAGE
  exit 64
end

case ARGV.shift
when "register-baseline"
  register_mas_baseline!
when "status"
  baseline_status!
when "patch"
  patch_mas_release!
else
  usage!
end
