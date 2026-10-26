#include "xue_hua_navite_drag_drop_plugin.h"

#include <flutter/encodable_value.h>
#include <flutter/method_result_functions.h>

#include <filesystem>

namespace xue_hua_navite_drag_drop {

namespace {

std::string WideToUtf8(const std::wstring& wstr) {
  if (wstr.empty()) return std::string();
  int size_needed = WideCharToMultiByte(
      CP_UTF8, 0, wstr.data(), static_cast<int>(wstr.size()),
      nullptr, 0, nullptr, nullptr);
  std::string result(size_needed, 0);
  WideCharToMultiByte(
      CP_UTF8, 0, wstr.data(), static_cast<int>(wstr.size()),
      result.data(), size_needed, nullptr, nullptr);
  return result;
}

std::wstring Utf8ToWide(const std::string& str) {
  if (str.empty()) return std::wstring();
  int size_needed = MultiByteToWideChar(
      CP_UTF8, 0, str.data(), static_cast<int>(str.size()), nullptr, 0);
  std::wstring result(size_needed, 0);
  MultiByteToWideChar(
      CP_UTF8, 0, str.data(), static_cast<int>(str.size()),
      result.data(), size_needed);
  return result;
}

flutter::EncodableMap SerializeFileOrFolder(const std::filesystem::path& p, int depth) {
  std::error_code ec;
  bool is_dir = std::filesystem::is_directory(p, ec);
  int64_t size = 0;
  flutter::EncodableList children;

  if (is_dir && depth < 3) {
    for (const auto& entry : std::filesystem::directory_iterator(p, ec)) {
      auto child_map = SerializeFileOrFolder(entry.path(), depth + 1);
      auto it = child_map.find(flutter::EncodableValue("size"));
      if (it != child_map.end()) {
        if (auto* val = std::get_if<int64_t>(&it->second)) {
          size += *val;
        }
      }
      children.push_back(flutter::EncodableValue(child_map));
    }
  } else if (!is_dir) {
    auto fsize = std::filesystem::file_size(p, ec);
    if (!ec) {
      size = static_cast<int64_t>(fsize);
    }
  }

  std::string utf8_path = WideToUtf8(p.wstring());
  std::string utf8_name = WideToUtf8(p.filename().wstring());
  if (utf8_name.empty()) {
    utf8_name = utf8_path;
  }

  return flutter::EncodableMap{
      {flutter::EncodableValue("name"), flutter::EncodableValue(utf8_name)},
      {flutter::EncodableValue("path"), flutter::EncodableValue(utf8_path)},
      {flutter::EncodableValue("uri"), flutter::EncodableValue("file:///" + utf8_path)},
      {flutter::EncodableValue("isDirectory"), flutter::EncodableValue(is_dir)},
      {flutter::EncodableValue("size"), flutter::EncodableValue(size)},
      {flutter::EncodableValue("children"), flutter::EncodableValue(children)},
  };
}

class SimpleDropSource : public IDropSource {
 public:
  SimpleDropSource() : ref_count_(1) {}
  virtual ~SimpleDropSource() = default;

  STDMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
    if (riid == IID_IUnknown || riid == IID_IDropSource) {
      *ppv = static_cast<IDropSource*>(this);
      AddRef();
      return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
  }

  STDMETHODIMP_(ULONG) AddRef() override {
    return InterlockedIncrement(&ref_count_);
  }

  STDMETHODIMP_(ULONG) Release() override {
    ULONG count = InterlockedDecrement(&ref_count_);
    if (count == 0) delete this;
    return count;
  }

  STDMETHODIMP QueryContinueDrag(BOOL fEscapePressed, DWORD grfKeyState) override {
    if (fEscapePressed) return DRAGDROP_S_CANCEL;
    if (!(grfKeyState & MK_LBUTTON)) return DRAGDROP_S_DROP;
    return S_OK;
  }

  STDMETHODIMP GiveFeedback(DWORD dwEffect) override {
    return DRAGDROP_S_USEDEFAULTCURSORS;
  }

 private:
  LONG ref_count_;
};

}  // namespace

class WindowsDropTarget : public IDropTarget {
 public:
  explicit WindowsDropTarget(XueHuaNaviteDragDropPlugin* plugin)
      : ref_count_(1), plugin_(plugin) {}

  virtual ~WindowsDropTarget() = default;

  STDMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
    if (riid == IID_IUnknown || riid == IID_IDropTarget) {
      *ppv = static_cast<IDropTarget*>(this);
      AddRef();
      return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
  }

  STDMETHODIMP_(ULONG) AddRef() override {
    return InterlockedIncrement(&ref_count_);
  }

  STDMETHODIMP_(ULONG) Release() override {
    ULONG count = InterlockedDecrement(&ref_count_);
    if (count == 0) delete this;
    return count;
  }

  STDMETHODIMP DragEnter(IDataObject* pDataObj, DWORD grfKeyState,
                         POINTL pt, DWORD* pdwEffect) override {
    auto coords = ConvertPoint(pt);
    if (plugin_->channel()) {
      plugin_->channel()->InvokeMethod(
          "onDragEntered",
          std::make_unique<flutter::EncodableValue>(coords));
    }
    *pdwEffect = plugin_->current_drop_effect();
    return S_OK;
  }

  STDMETHODIMP DragOver(DWORD grfKeyState, POINTL pt, DWORD* pdwEffect) override {
    auto coords = ConvertPoint(pt);
    if (plugin_->channel()) {
      plugin_->channel()->InvokeMethod(
          "onDragUpdated",
          std::make_unique<flutter::EncodableValue>(coords));
    }
    *pdwEffect = plugin_->current_drop_effect();
    return S_OK;
  }

  STDMETHODIMP DragLeave() override {
    if (plugin_->channel()) {
      plugin_->channel()->InvokeMethod(
          "onDragExited",
          std::make_unique<flutter::EncodableValue>());
    }
    return S_OK;
  }

  STDMETHODIMP Drop(IDataObject* pDataObj, DWORD grfKeyState,
                    POINTL pt, DWORD* pdwEffect) override {
    if (plugin_->current_drop_effect() == DROPEFFECT_NONE) {
      *pdwEffect = DROPEFFECT_NONE;
      return S_OK;
    }

    FORMATETC fmt = {CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
    STGMEDIUM stg = {};
    flutter::EncodableList dropped_items;

    if (SUCCEEDED(pDataObj->GetData(&fmt, &stg))) {
      HDROP hdrop = static_cast<HDROP>(GlobalLock(stg.hGlobal));
      if (hdrop) {
        UINT file_count = DragQueryFileW(hdrop, 0xFFFFFFFF, nullptr, 0);
        for (UINT i = 0; i < file_count; ++i) {
          UINT len = DragQueryFileW(hdrop, i, nullptr, 0);
          if (len > 0) {
            std::wstring path_buf(len + 1, L'\0');
            DragQueryFileW(hdrop, i, path_buf.data(), len + 1);
            path_buf.resize(len);
            dropped_items.push_back(flutter::EncodableValue(
                SerializeFileOrFolder(std::filesystem::path(path_buf), 0)));
          }
        }
        GlobalUnlock(stg.hGlobal);
      }
      ReleaseStgMedium(&stg);
    }

    auto payload = ConvertPoint(pt);
    payload[flutter::EncodableValue("items")] =
        flutter::EncodableValue(dropped_items);
    if (plugin_->channel()) {
      plugin_->channel()->InvokeMethod(
          "onPerformDrop",
          std::make_unique<flutter::EncodableValue>(payload));
    }

    *pdwEffect = plugin_->current_drop_effect();
    return S_OK;
  }

 private:
  flutter::EncodableMap ConvertPoint(POINTL pt) const {
    POINT client_pt = {pt.x, pt.y};
    HWND hwnd = plugin_->GetHwnd();
    double scale = 1.0;
    if (hwnd) {
      ScreenToClient(hwnd, &client_pt);
      UINT dpi = GetDpiForWindow(hwnd);
      if (dpi > 0) {
        scale = static_cast<double>(dpi) / 96.0;
      }
    }
    return flutter::EncodableMap{
        {flutter::EncodableValue("x"),
         flutter::EncodableValue(static_cast<double>(client_pt.x) / scale)},
        {flutter::EncodableValue("y"),
         flutter::EncodableValue(static_cast<double>(client_pt.y) / scale)},
    };
  }

  LONG ref_count_;
  XueHuaNaviteDragDropPlugin* plugin_;
};

// static
void XueHuaNaviteDragDropPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "xue_hua_navite_drag_drop",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<XueHuaNaviteDragDropPlugin>(
      registrar, std::move(channel));

  plugin->channel()->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

XueHuaNaviteDragDropPlugin::XueHuaNaviteDragDropPlugin() {
  OleInitialize(nullptr);
}

XueHuaNaviteDragDropPlugin::XueHuaNaviteDragDropPlugin(
    flutter::PluginRegistrarWindows *registrar,
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel)
    : registrar_(registrar), channel_(std::move(channel)) {
  OleInitialize(nullptr);
}

XueHuaNaviteDragDropPlugin::~XueHuaNaviteDragDropPlugin() {
  if (registered_hwnd_ && drop_target_) {
    RevokeDragDrop(registered_hwnd_);
    drop_target_->Release();
    drop_target_ = nullptr;
  }
  OleUninitialize();
}

HWND XueHuaNaviteDragDropPlugin::GetHwnd() const {
  if (registrar_ && registrar_->GetView()) {
    return registrar_->GetView()->GetNativeWindow();
  }
  return nullptr;
}

void XueHuaNaviteDragDropPlugin::EnsureDropTargetRegistered() {
  HWND hwnd = GetHwnd();
  if (!hwnd || registered_hwnd_ == hwnd) {
    return;
  }
  drop_target_ = new WindowsDropTarget(this);
  RegisterDragDrop(hwnd, drop_target_);
  registered_hwnd_ = hwnd;
}

// Build a CF_HDROP HGLOBAL for existing filesystem paths. Explorer/Desktop
// requires CF_HDROP for file drops; SHCreateDataObject alone only guarantees
// CFSTR_SHELLIDLIST and needs parent+relative child PIDLs (not absolute ones).
HGLOBAL CreateHDropGlobal(const std::vector<std::wstring>& file_paths) {
  size_t bytes = sizeof(DROPFILES);
  for (const auto& path : file_paths) {
    bytes += (path.size() + 1) * sizeof(wchar_t);
  }
  bytes += sizeof(wchar_t);  // final double-null terminator

  HGLOBAL hg = GlobalAlloc(GHND, bytes);
  if (!hg) {
    return nullptr;
  }
  auto* drop_files = static_cast<DROPFILES*>(GlobalLock(hg));
  if (!drop_files) {
    GlobalFree(hg);
    return nullptr;
  }
  drop_files->pFiles = sizeof(DROPFILES);
  drop_files->pt = {0, 0};
  drop_files->fNC = FALSE;
  drop_files->fWide = TRUE;

  wchar_t* dest = reinterpret_cast<wchar_t*>(
      reinterpret_cast<BYTE*>(drop_files) + sizeof(DROPFILES));
  for (const auto& path : file_paths) {
    const size_t len = path.size() + 1;
    wmemcpy(dest, path.c_str(), len);
    dest += len;
  }
  *dest = L'\0';
  GlobalUnlock(hg);
  return hg;
}

// Minimal IDataObject that exposes CF_HDROP so Desktop/Explorer accept the drag.
class HDropDataObject : public IDataObject {
 public:
  explicit HDropDataObject(HGLOBAL hdrop) : ref_count_(1), hdrop_(hdrop) {}
  virtual ~HDropDataObject() {
    if (hdrop_) {
      GlobalFree(hdrop_);
      hdrop_ = nullptr;
    }
  }

  STDMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
    if (riid == IID_IUnknown || riid == IID_IDataObject) {
      *ppv = static_cast<IDataObject*>(this);
      AddRef();
      return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
  }

  STDMETHODIMP_(ULONG) AddRef() override {
    return InterlockedIncrement(&ref_count_);
  }

  STDMETHODIMP_(ULONG) Release() override {
    ULONG count = InterlockedDecrement(&ref_count_);
    if (count == 0) delete this;
    return count;
  }

  STDMETHODIMP GetData(FORMATETC* pformatetc, STGMEDIUM* pmedium) override {
    if (!pformatetc || !pmedium || !hdrop_) {
      return E_INVALIDARG;
    }
    if (pformatetc->cfFormat != CF_HDROP ||
        !(pformatetc->tymed & TYMED_HGLOBAL) ||
        pformatetc->dwAspect != DVASPECT_CONTENT) {
      return DV_E_FORMATETC;
    }
    HGLOBAL copy = OleDuplicateData(hdrop_, CF_HDROP, GMEM_MOVEABLE);
    if (!copy) {
      return E_OUTOFMEMORY;
    }
    pmedium->tymed = TYMED_HGLOBAL;
    pmedium->hGlobal = copy;
    pmedium->pUnkForRelease = nullptr;
    return S_OK;
  }

  STDMETHODIMP GetDataHere(FORMATETC*, STGMEDIUM*) override {
    return E_NOTIMPL;
  }

  STDMETHODIMP QueryGetData(FORMATETC* pformatetc) override {
    if (!pformatetc) {
      return E_INVALIDARG;
    }
    if (pformatetc->cfFormat == CF_HDROP &&
        (pformatetc->tymed & TYMED_HGLOBAL) &&
        pformatetc->dwAspect == DVASPECT_CONTENT) {
      return S_OK;
    }
    return DV_E_FORMATETC;
  }

  STDMETHODIMP GetCanonicalFormatEtc(FORMATETC*, FORMATETC* pformatetcOut) override {
    if (!pformatetcOut) {
      return E_INVALIDARG;
    }
    pformatetcOut->ptd = nullptr;
    return DATA_S_SAMEFORMATETC;
  }

  STDMETHODIMP SetData(FORMATETC*, STGMEDIUM*, BOOL) override {
    return E_NOTIMPL;
  }

  STDMETHODIMP EnumFormatEtc(DWORD dwDirection, IEnumFORMATETC** ppenumFormatEtc) override {
    if (!ppenumFormatEtc) {
      return E_INVALIDARG;
    }
    if (dwDirection != DATADIR_GET) {
      return E_NOTIMPL;
    }
    FORMATETC fmt = {CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
    return SHCreateStdEnumFmtEtc(1, &fmt, ppenumFormatEtc);
  }

  STDMETHODIMP DAdvise(FORMATETC*, DWORD, IAdviseSink*, DWORD*) override {
    return OLE_E_ADVISENOTSUPPORTED;
  }

  STDMETHODIMP DUnadvise(DWORD) override {
    return OLE_E_ADVISENOTSUPPORTED;
  }

  STDMETHODIMP EnumDAdvise(IEnumSTATDATA**) override {
    return OLE_E_ADVISENOTSUPPORTED;
  }

 private:
  LONG ref_count_;
  HGLOBAL hdrop_;
};

void XueHuaNaviteDragDropPlugin::NotifyDragOutEnded(bool success) {
  if (!channel_) {
    return;
  }
  channel_->InvokeMethod(
      "onDragOutEnded",
      std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
          {flutter::EncodableValue("success"), flutter::EncodableValue(success)},
      }));
}

void XueHuaNaviteDragDropPlugin::StartDragOutWithPaths(
    const std::vector<std::wstring>& file_paths) {
  // Only existing filesystem paths can be offered via CF_HDROP.
  std::vector<std::wstring> existing_paths;
  existing_paths.reserve(file_paths.size());
  for (const auto& path : file_paths) {
    std::error_code ec;
    if (!path.empty() && std::filesystem::exists(path, ec) && !ec) {
      existing_paths.push_back(path);
    }
  }
  if (existing_paths.empty()) {
    NotifyDragOutEnded(false);
    return;
  }

  // OLE DoDragDrop can hang indefinitely when neither mouse button is down
  // (common in flutter_driver / automated sessions). Bail out cleanly instead.
  const bool button_down =
      (GetAsyncKeyState(VK_LBUTTON) & 0x8000) != 0 ||
      (GetAsyncKeyState(VK_RBUTTON) & 0x8000) != 0;
  if (!button_down) {
    NotifyDragOutEnded(false);
    return;
  }

  HGLOBAL hdrop = CreateHDropGlobal(existing_paths);
  IDataObject* data_obj = hdrop ? new HDropDataObject(hdrop) : nullptr;

  bool drag_succeeded = false;
  if (data_obj) {
    auto* drop_source = new SimpleDropSource();
    DWORD effect = DROPEFFECT_NONE;
    // Desktop/Explorer accept COPY for CF_HDROP file drops. MOVE is also
    // offered so targets that prefer move can request it.
    HRESULT drag_hr = DoDragDrop(
        data_obj, drop_source, DROPEFFECT_COPY | DROPEFFECT_MOVE, &effect);
    drag_succeeded = (drag_hr == DRAGDROP_S_DROP && effect != DROPEFFECT_NONE);
    drop_source->Release();
    data_obj->Release();
  }

  NotifyDragOutEnded(drag_succeeded);
}

void XueHuaNaviteDragDropPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method = method_call.method_name();

  if (method == "initDragDrop") {
    EnsureDropTargetRegistered();
    result->Success();
    return;
  }

  if (method == "setDropEffect") {
    if (const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments())) {
      auto it = args->find(flutter::EncodableValue("operation"));
      if (it != args->end()) {
        if (const auto* op = std::get_if<std::string>(&it->second)) {
          if (*op == "none") {
            current_drop_effect_ = DROPEFFECT_NONE;
          } else if (*op == "move") {
            current_drop_effect_ = DROPEFFECT_MOVE;
          } else if (*op == "link") {
            current_drop_effect_ = DROPEFFECT_LINK;
          } else {
            current_drop_effect_ = DROPEFFECT_COPY;
          }
        }
      }
    }
    result->Success();
    return;
  }

  if (method == "startDragOut") {
    EnsureDropTargetRegistered();
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!args) {
      result->Success(flutter::EncodableValue(false));
      return;
    }
    auto items_it = args->find(flutter::EncodableValue("items"));
    if (items_it == args->end()) {
      result->Success(flutter::EncodableValue(false));
      return;
    }
    const auto* items_list = std::get_if<flutter::EncodableList>(&items_it->second);
    if (!items_list || items_list->empty()) {
      result->Success(flutter::EncodableValue(false));
      return;
    }

    auto resolved_paths = std::make_shared<std::vector<std::wstring>>();
    auto pending_async = std::make_shared<int>(0);

    std::filesystem::path temp_dir =
        std::filesystem::temp_directory_path() / L"xue_hua_drag_drop";
    std::error_code ec;
    std::filesystem::create_directories(temp_dir, ec);

    for (const auto& item_val : *items_list) {
      const auto* item_map = std::get_if<flutter::EncodableMap>(&item_val);
      if (!item_map) continue;

      bool is_async = false;
      auto async_it = item_map->find(flutter::EncodableValue("isAsync"));
      if (async_it != item_map->end()) {
        if (const auto* b = std::get_if<bool>(&async_it->second)) is_async = *b;
      }

      std::string file_path_str;
      auto path_it = item_map->find(flutter::EncodableValue("filePath"));
      if (path_it != item_map->end()) {
        if (const auto* s = std::get_if<std::string>(&path_it->second)) {
          file_path_str = *s;
        }
      }

      if (!is_async) {
        // Mode A: only keep non-empty paths that currently exist on disk.
        if (file_path_str.empty()) {
          continue;
        }
        std::wstring wide_path = Utf8ToWide(file_path_str);
        std::error_code exists_ec;
        if (std::filesystem::exists(wide_path, exists_ec) && !exists_ec) {
          resolved_paths->push_back(std::move(wide_path));
        }
        continue;
      }

      if (!channel_) {
        continue;
      }

      std::string item_id;
      std::string file_name = "exported_file";
      auto id_it = item_map->find(flutter::EncodableValue("id"));
      if (id_it != item_map->end()) {
        if (const auto* s = std::get_if<std::string>(&id_it->second)) item_id = *s;
      }
      auto name_it = item_map->find(flutter::EncodableValue("fileName"));
      if (name_it != item_map->end()) {
        if (const auto* s = std::get_if<std::string>(&name_it->second)) file_name = *s;
      }

      std::filesystem::path target_file = temp_dir / Utf8ToWide(file_name);
      std::wstring target_wide = target_file.wstring();
      std::string target_utf8 = WideToUtf8(target_wide);

      (*pending_async)++;
      channel_->InvokeMethod(
          "onRequestAsyncFileWrite",
          std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
              {flutter::EncodableValue("id"), flutter::EncodableValue(item_id)},
              {flutter::EncodableValue("destinationPath"),
               flutter::EncodableValue(target_utf8)},
          }),
          std::make_unique<flutter::MethodResultFunctions<flutter::EncodableValue>>(
              [this, resolved_paths, pending_async, target_wide](
                  const flutter::EncodableValue* reply) {
                if (reply) {
                  if (const auto* ok = std::get_if<bool>(reply); ok && *ok) {
                    resolved_paths->push_back(target_wide);
                  }
                }
                (*pending_async)--;
                if (*pending_async == 0) {
                  StartDragOutWithPaths(*resolved_paths);
                }
              },
              [this, resolved_paths, pending_async](
                  const std::string&, const std::string&,
                  const flutter::EncodableValue*) {
                (*pending_async)--;
                if (*pending_async == 0) {
                  StartDragOutWithPaths(*resolved_paths);
                }
              },
              [this, resolved_paths, pending_async]() {
                (*pending_async)--;
                if (*pending_async == 0) {
                  StartDragOutWithPaths(*resolved_paths);
                }
              }));
    }

    // Mirror Linux: do not claim success when there is nothing valid to drag.
    if (*pending_async == 0) {
      if (resolved_paths->empty()) {
        result->Success(flutter::EncodableValue(false));
        return;
      }
      result->Success(flutter::EncodableValue(true));
      StartDragOutWithPaths(*resolved_paths);
      return;
    }

    result->Success(flutter::EncodableValue(true));
    return;
  }

  result->NotImplemented();
}

}  // namespace xue_hua_navite_drag_drop
