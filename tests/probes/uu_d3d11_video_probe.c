#define COBJMACROS
#include <windows.h>
#include <dxgi1_2.h>
#include <d3d11.h>
#include <stdio.h>
#include <string.h>

static const GUID h264 = {0x1b81be68, 0xa0c7, 0x11d3, {0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5}};

static int expect_hr(const char *name, HRESULT actual, HRESULT expected)
{
    printf("%s hr=%08lx expected=%08lx\n", name, (unsigned long)actual, (unsigned long)expected);
    return actual != expected;
}

static int check_video(ID3D11VideoDevice *video)
{
    D3D11_VIDEO_DECODER_DESC desc = {h264, 3840, 2160, DXGI_FORMAT_NV12};
    D3D11_VIDEO_DECODER_CONFIG config = {0};
    BOOL supported = FALSE;
    UINT count = 0;
    int failures = 0;
    HRESULT hr = ID3D11VideoDevice_CheckVideoDecoderFormat(video, &h264, DXGI_FORMAT_NV12, &supported);
    failures += expect_hr("CheckVideoDecoderFormat", hr, S_OK);
    printf("h264_nv12=%d\n", supported);
    failures += !supported;
    hr = ID3D11VideoDevice_GetVideoDecoderConfigCount(video, &desc, &count);
    failures += expect_hr("GetVideoDecoderConfigCount", hr, S_OK);
    printf("config_count=%u\n", count);
    failures += !count;
    hr = ID3D11VideoDevice_GetVideoDecoderConfig(video, &desc, 0, &config);
    failures += expect_hr("GetVideoDecoderConfig", hr, S_OK);
    printf("bitstream_raw=%u\n", config.ConfigBitstreamRaw);

    supported = TRUE;
    hr = ID3D11VideoDevice_CheckVideoDecoderFormat(video, &h264, DXGI_FORMAT_R8G8B8A8_UNORM, &supported);
    failures += expect_hr("unsupported_format", hr, S_OK);
    failures += supported != FALSE;
    failures += expect_hr("null_profile", ID3D11VideoDevice_CheckVideoDecoderFormat(
        video, NULL, DXGI_FORMAT_NV12, &supported), E_INVALIDARG);
    failures += expect_hr("null_desc", ID3D11VideoDevice_GetVideoDecoderConfigCount(
        video, NULL, &count), E_INVALIDARG);
    failures += expect_hr("invalid_index", ID3D11VideoDevice_GetVideoDecoderConfig(
        video, &desc, ~0u, &config), E_INVALIDARG);
    desc.SampleWidth = 0;
    failures += expect_hr("zero_width", ID3D11VideoDevice_GetVideoDecoderConfigCount(
        video, &desc, &count), E_INVALIDARG);
    return failures;
}

int main(int argc, char **argv)
{
    IDXGIFactory1 *factory = NULL;
    HRESULT hr;
    UINT adapters = 0;
    int failures = 0;
    if (argc == 2 && !strcmp(argv[1], "--help")) {
        puts("D3D11 H.264 query probe: checks every DXGI adapter; does not decode video.");
        return 0;
    }
    if (argc != 1) return 2;
    hr = CreateDXGIFactory1(&IID_IDXGIFactory1, (void **)&factory);
    if (expect_hr("CreateDXGIFactory1", hr, S_OK)) return 1;
    for (UINT index = 0; ; ++index) {
        IDXGIAdapter1 *adapter = NULL;
        ID3D11Device *device = NULL;
        ID3D11DeviceContext *context = NULL;
        ID3D11VideoDevice *video = NULL;
        DXGI_ADAPTER_DESC1 desc = {0};
        D3D_FEATURE_LEVEL level = 0;
        hr = IDXGIFactory1_EnumAdapters1(factory, index, &adapter);
        if (hr == DXGI_ERROR_NOT_FOUND) break;
        if (expect_hr("EnumAdapters1", hr, S_OK)) { ++failures; break; }
        ++adapters;
        hr = IDXGIAdapter1_GetDesc1(adapter, &desc);
        failures += expect_hr("GetDesc1", hr, S_OK);
        printf("adapter=%u luid=%llu vendor=%u device=%u vram=%llu\n", index,
            ((unsigned long long)(DWORD)desc.AdapterLuid.HighPart << 32) | desc.AdapterLuid.LowPart,
            desc.VendorId, desc.DeviceId, (unsigned long long)desc.DedicatedVideoMemory);
        hr = D3D11CreateDevice((IDXGIAdapter *)adapter, D3D_DRIVER_TYPE_UNKNOWN, NULL,
            D3D11_CREATE_DEVICE_VIDEO_SUPPORT | D3D11_CREATE_DEVICE_BGRA_SUPPORT,
            NULL, 0, D3D11_SDK_VERSION, &device, &level, &context);
        failures += expect_hr("D3D11CreateDevice", hr, S_OK);
        if (SUCCEEDED(hr)) {
            D3D11_FEATURE_DATA_D3D11_OPTIONS options = {0};
            hr = ID3D11Device_CheckFeatureSupport(device, D3D11_FEATURE_D3D11_OPTIONS, &options, sizeof(options));
            printf("D3D11_OPTIONS hr=%08lx ExtendedResourceSharing=%d\n", (unsigned long)hr, options.ExtendedResourceSharing);
            hr = ID3D11Device_QueryInterface(device, &IID_ID3D11VideoDevice, (void **)&video);
            failures += expect_hr("ID3D11VideoDevice", hr, S_OK);
            if (SUCCEEDED(hr)) {
                failures += check_video(video);
                ID3D11VideoDevice_Release(video);
            }
            ID3D11DeviceContext_Release(context);
            ID3D11Device_Release(device);
        }
        IDXGIAdapter1_Release(adapter);
    }
    IDXGIFactory1_Release(factory);
    printf("adapters=%u query_failures=%d; no decode performed\n", adapters, failures);
    return failures || !adapters ? 1 : 0;
}
