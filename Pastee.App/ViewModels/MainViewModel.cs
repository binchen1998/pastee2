using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media.Imaging;
using Pastee.App.Infrastructure;
using Pastee.App.Models;
using Pastee.App.Services;

namespace Pastee.App.ViewModels
{
    public class MainViewModel : INotifyPropertyChanged
    {
        private readonly LocalDataStore _dataStore = new LocalDataStore();
        private readonly RemoteSyncService _remoteSync;
        private readonly ApiService _apiService = new ApiService();
        private readonly WebSocketService _wsService = new WebSocketService();
        
        private string _searchInput = string.Empty;
        private string _searchText = string.Empty;
        private string _lastEntrySignature = string.Empty;
        private string _wsStatus = "Disconnected";
        private string _wsStatusColor = "#e74c3c";
        private bool _isLoading;
        private bool _hasMore = true;
        private int _currentPage = 1;
        private const int DefaultPageSize = 20;
        private string _selectedCategory = "all";
        private bool _isStorageLimitReached;
        private System.Threading.CancellationTokenSource? _fetchCts;
        private DateTimeOffset _lastCopyTime = DateTimeOffset.MinValue;
        private int _draftCount;
        private string _deviceId = string.Empty;
        private string _userEmail = string.Empty;
        private string _currentHotkey = "Win + V";
        private bool _hideAfterPaste = true;
        private string _loadingText = "Loading...";

        public ObservableCollection<ClipboardEntry> Items { get; } = new ObservableCollection<ClipboardEntry>();
        public ObservableCollection<Category> Categories { get; } = new ObservableCollection<Category>();
        public ICollectionView FilteredItems { get; }

        public string LoadingText
        {
            get => _loadingText;
            set { _loadingText = value; OnPropertyChanged(nameof(LoadingText)); }
        }

        public string SearchInput
        {
            get => _searchInput;
            set { _searchInput = value; OnPropertyChanged(nameof(SearchInput)); }
        }

        public string SearchText
        {
            get => _searchText;
            set { _searchText = value; OnPropertyChanged(nameof(SearchText)); }
        }

        public string UserEmail
        {
            get => _userEmail;
            set { _userEmail = value; OnPropertyChanged(nameof(UserEmail)); }
        }

        public string DeviceId => _deviceId;

        public int DraftCount
        {
            get => _draftCount;
            set { _draftCount = value; OnPropertyChanged(nameof(DraftCount)); }
        }

        public bool IsLoading
        {
            get => _isLoading;
            set 
            { 
                _isLoading = value; 
                OnPropertyChanged(nameof(IsLoading)); 
                LoadMoreCommand.RaiseCanExecuteChanged();
            }
        }

        public string SelectedCategory
        {
            get => _selectedCategory;
            set { _selectedCategory = value; OnPropertyChanged(nameof(SelectedCategory)); }
        }

        public bool IsStorageLimitReached
        {
            get => _isStorageLimitReached;
            set { _isStorageLimitReached = value; OnPropertyChanged(nameof(IsStorageLimitReached)); }
        }

        public string WsStatus
        {
            get => _wsStatus;
            set { _wsStatus = value; OnPropertyChanged(nameof(WsStatus)); }
        }

        public string WsStatusColor
        {
            get => _wsStatusColor;
            set { _wsStatusColor = value; OnPropertyChanged(nameof(WsStatusColor)); }
        }

        public string CurrentHotkey
        {
            get => _currentHotkey;
            set 
            { 
                if (_currentHotkey == value) return;
                _currentHotkey = value; 
                OnPropertyChanged(nameof(CurrentHotkey)); 
                
                // 自动保存热键配置
                _ = _dataStore.SaveWindowSettingsAsync(0, 0, _currentHotkey);
            }
        }

        public bool HideAfterPaste
        {
            get => _hideAfterPaste;
            set
            {
                if (_hideAfterPaste == value) return;
                _hideAfterPaste = value;
                OnPropertyChanged(nameof(HideAfterPaste));
                
                // 自动保存设置
                _ = _dataStore.SaveWindowSettingsAsync(0, 0, null, _hideAfterPaste);
            }
        }

        public RelayCommand DeleteCommand { get; }
        public RelayCommand EditCommand { get; }
        public RelayCommand ReconnectCommand { get; }
        public RelayCommand LoadMoreCommand { get; }
        public RelayCommand ToggleBookmarkCommand { get; }
        public RelayCommand RefreshCommand { get; }
        public RelayCommand SelectCategoryCommand { get; }
        public RelayCommand AddToCategoryCommand { get; }
        public RelayCommand CreateCategoryCommand { get; }
        public RelayCommand UpdateCategoryCommand { get; }
        public RelayCommand DeleteCategoryCommand { get; }
        public RelayCommand RefreshCategoriesCommand { get; }
        public RelayCommand CopyItemCommand { get; }
        public RelayCommand RetryUploadCommand { get; }
        public RelayCommand CommitSearchCommand { get; }
        public RelayCommand ViewImageCommand { get; }
        public RelayCommand ClearAllDraftsCommand { get; }

        public MainViewModel()
        {
            var authService = new AuthService();
            _deviceId = authService.GetOrCreateDeviceId();
            _remoteSync = new RemoteSyncService(_apiService, _deviceId);
            
            FilteredItems = CollectionViewSource.GetDefaultView(Items);
            FilteredItems.SortDescriptions.Add(new SortDescription(nameof(ClipboardEntry.CreatedAt), ListSortDirection.Descending));
            FilteredItems.Filter = FilterItem;

            DeleteCommand = new RelayCommand(p =>
            {
                var entry = p as ClipboardEntry;
                if (entry != null)
                {
                    DeleteEntry(entry);
                }
            });

            EditCommand = new RelayCommand(p =>
            {
                var entry = p as ClipboardEntry;
                if (entry != null)
                {
                    var handler = RequestEdit;
                    if (handler != null)
                    {
                        handler(this, entry);
                    }
                }
            });

            ToggleBookmarkCommand = new RelayCommand(async p =>
            {
                var entry = p as ClipboardEntry;
                if (entry != null)
                {
                    await ToggleBookmarkAsync(entry);
                }
            });

            ReconnectCommand = new RelayCommand(async _ => await InitializeRealtimeAsync(true));
            LoadMoreCommand = new RelayCommand(async _ => await FetchItemsAsync(_currentPage + 1), _ => !IsLoading && _hasMore);
            RefreshCommand = new RelayCommand(async _ => await FetchItemsAsync(1));
            RefreshCategoriesCommand = new RelayCommand(async _ => await FetchCategoriesAsync());
            CopyItemCommand = new RelayCommand(p =>
            {
                var entry = p as ClipboardEntry;
                if (entry != null)
                {
                    CopyEntryToClipboard(entry);
                }
            });

            SelectCategoryCommand = new RelayCommand(async p => 
            {
                var catName = p as string;
                if (!string.IsNullOrEmpty(catName))
                {
                    // 1. 立即清空列表，确保视觉反馈即时
                    Items.Clear();
                    
                    SelectedCategory = catName;
                    SearchInput = string.Empty; 
                    SearchText = string.Empty; // 切换分类时清空所有搜索状态
                    
                    // 更新分类列表中的选中状态
                    foreach (var c in Categories)
                    {
                        c.IsSelected = (c.Name == catName);
                    }
                    
                    await FetchItemsAsync(1);
                }
            });

            CommitSearchCommand = new RelayCommand(async _ =>
            {
                SearchText = SearchInput;
                await FetchItemsAsync(1);
            });

            AddToCategoryCommand = new RelayCommand(async p =>
            {
                if (p is object[] parameters && parameters.Length == 2)
                {
                    var item = parameters[0] as ClipboardEntry;
                    var category = parameters[1] as Category;
                    if (item != null && category != null)
                    {
                        await AddItemToCategoryAsync(category.Id, item.Id);
                    }
                }
            });

            CreateCategoryCommand = new RelayCommand(async _ =>
            {
                var activeWindow = GetActiveWindow();
                var dialog = new Pastee.App.Views.EditTextWindow(string.Empty, "Category Name:", 15, false) 
                { 
                    Title = "New Category",
                    Owner = activeWindow
                };
                if (dialog.ShowDialog() == true && !string.IsNullOrWhiteSpace(dialog.EditedText))
                {
                    await CreateCategoryAsync(dialog.EditedText.Trim());
                }
            });

            UpdateCategoryCommand = new RelayCommand(async p =>
            {
                var category = p as Category;
                if (category != null)
                {
                    var activeWindow = GetActiveWindow();
                    var dialog = new Pastee.App.Views.EditTextWindow(category.Name, "Category Name:", 15, false) 
                    { 
                        Title = "Edit Category Name",
                        Owner = activeWindow
                    };
                    if (dialog.ShowDialog() == true && !string.IsNullOrWhiteSpace(dialog.EditedText))
                    {
                        await UpdateCategoryAsync(category.Id, dialog.EditedText.Trim());
                    }
                }
            });

            DeleteCategoryCommand = new RelayCommand(async p =>
            {
                var category = p as Category;
                if (category != null)
                {
                    var activeWindow = GetActiveWindow();
                    var dialog = new Pastee.App.Views.ConfirmWindow($"Are you sure you want to delete category '{category.Name}'?")
                    {
                        Owner = activeWindow
                    };
                    if (dialog.ShowDialog() == true)
                    {
                        await DeleteCategoryAsync(category.Id);
                    }
                }
            });

            RetryUploadCommand = new RelayCommand(async p =>
            {
                var entry = p as ClipboardEntry;
                if (entry != null)
                {
                    await PerformUploadAsync(entry);
                }
            });

            ViewImageCommand = new RelayCommand(p =>
            {
                var entry = p as ClipboardEntry;
                if (entry != null && entry.ContentType == "image")
                {
                    var activeWindow = GetActiveWindow();
                    var imageWindow = new Pastee.App.Views.ImageViewWindow(entry);
                    if (activeWindow != null)
                    {
                        imageWindow.Owner = activeWindow;
                        imageWindow.WindowStartupLocation = WindowStartupLocation.CenterOwner;
                    }
                    imageWindow.Show();
                }
            });

            ClearAllDraftsCommand = new RelayCommand(async _ =>
            {
                await ClearAllDraftsAsync();
            }, _ => DraftCount > 0);

            _wsService.Connected += (s, e) => { WsStatus = "Connected"; WsStatusColor = "#2ecc71"; };
            _wsService.Disconnected += (s, e) => { WsStatus = "Disconnected"; WsStatusColor = "#e74c3c"; };
            _wsService.Connecting += (s, e) => { WsStatus = "Connecting..."; WsStatusColor = "#f39c12"; };
            _wsService.MessageReceived += OnWebSocketMessageReceived;
            _apiService.StorageLimitReached += (s, e) => IsStorageLimitReached = true;
        }

        private void OnWebSocketMessageReceived(object? sender, string message)
        {
            System.Diagnostics.Debug.WriteLine($"[MainVM] 收到 WebSocket 原始消息: {message}");
            try
            {
                using (var doc = JsonDocument.Parse(message))
                {
                    // 兼容后端不同的事件字段名 (event 或 type)
                    string eventType = string.Empty;
                    if (doc.RootElement.TryGetProperty("event", out var eventProp))
                        eventType = eventProp.GetString() ?? string.Empty;
                    else if (doc.RootElement.TryGetProperty("type", out var typeProp))
                        eventType = typeProp.GetString() ?? string.Empty;

                    if (string.IsNullOrEmpty(eventType))
                    {
                        System.Diagnostics.Debug.WriteLine("[MainVM] 消息中未找到 event 或 type 字段");
                        return;
                    }

                    System.Diagnostics.Debug.WriteLine($"[MainVM] 识别到事件类型: {eventType}");

                    Application.Current.Dispatcher.Invoke(async () =>
                    {
                        try
                        {
                            switch (eventType)
                            {
                                case "new_item":
                                case "item_created":
                                case "created":
                                    await HandleNewItemAsync(doc.RootElement);
                                    break;

                                case "update_item":
                                    if (doc.RootElement.TryGetProperty("data", out var updateData))
                                    {
                                        var updatedItem = JsonSerializer.Deserialize<ClipboardEntry>(updateData.GetRawText(), _apiService.GetJsonOptions());
                                        if (updatedItem != null)
                                        {
                                            var existing = Items.FirstOrDefault(i => i.Id == updatedItem.Id);
                                            if (existing != null)
                                            {
                                                System.Diagnostics.Debug.WriteLine($"[MainVM] 正在更新条目: {updatedItem.Id}");
                                                existing.Content = updatedItem.Content;
                                                existing.IsBookmarked = updatedItem.IsBookmarked;
                                                existing.InitializeImageState();
                                            }
                                        }
                                    }
                                    break;

                                case "delete_item":
                                    string? idToDelete = null;
                                    if (doc.RootElement.TryGetProperty("data", out var delData))
                                    {
                                        if (delData.ValueKind == JsonValueKind.Object && delData.TryGetProperty("id", out var idProp))
                                        {
                                            // 关键修复：处理数字类型的 ID
                                            if (idProp.ValueKind == JsonValueKind.Number)
                                                idToDelete = idProp.GetInt64().ToString();
                                            else
                                                idToDelete = idProp.GetString();
                                        }
                                        else if (delData.ValueKind == JsonValueKind.String)
                                        {
                                            idToDelete = delData.GetString();
                                        }
                                    }

                                    if (!string.IsNullOrEmpty(idToDelete))
                                    {
                                        var toRemove = Items.FirstOrDefault(i => i.Id == idToDelete);
                                        if (toRemove != null)
                                        {
                                            System.Diagnostics.Debug.WriteLine($"[MainVM] 远程通知删除条目: {idToDelete}");
                                            Items.Remove(toRemove);
                                        }
                                        else
                                        {
                                            System.Diagnostics.Debug.WriteLine($"[MainVM] 找不到要删除的条目: {idToDelete}");
                                        }
                                    }
                                    break;

                                case "sync":
                                    System.Diagnostics.Debug.WriteLine("[MainVM] 收到全局同步请求");
                                    await FetchItemsAsync(1);
                                    break;

                                default:
                                    System.Diagnostics.Debug.WriteLine($"[MainVM] 未处理的事件类型: {eventType}");
                                    break;
                            }
                        }
                        catch (Exception innerEx)
                        {
                            System.Diagnostics.Debug.WriteLine($"[MainVM] 处理事件 {eventType} 时异常: {innerEx.Message}");
                        }
                    });
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 解析 WebSocket 消息整体失败: {ex.Message}");
            }
        }

        private async Task HandleNewItemAsync(JsonElement root)
        {
            ClipboardEntry? item = null;
            
            // 尝试从 data 字段获取
            if (root.TryGetProperty("data", out var dataElement))
            {
                item = JsonSerializer.Deserialize<ClipboardEntry>(dataElement.GetRawText(), _apiService.GetJsonOptions());
            }
            // 尝试从 item 字段获取
            else if (root.TryGetProperty("item", out var itemElement))
            {
                item = JsonSerializer.Deserialize<ClipboardEntry>(itemElement.GetRawText(), _apiService.GetJsonOptions());
            }
            // 尝试直接从根对象获取（如果根对象本身就是 item）
            else if (root.TryGetProperty("id", out _))
            {
                item = JsonSerializer.Deserialize<ClipboardEntry>(root.GetRawText(), _apiService.GetJsonOptions());
            }

            if (item != null)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 准备插入新条目: {item.Id}");
                
                // 检查是否已存在（避免重复）
                if (Items.All(i => i.Id != item.Id))
                {
                    item.InitializeImageState();
                    Items.Insert(0, item);
                    System.Diagnostics.Debug.WriteLine($"[MainVM] 条目 {item.Id} 插入成功，当前列表数量: {Items.Count}");
                    
                    // 如果是图片且只有缩略图，自动下载原图
                    if (item.ContentType == "image" && item.IsThumbnail && !item.OriginalDeleted)
                    {
                        System.Diagnostics.Debug.WriteLine($"[MainVM] 触发自动下载原图: {item.Id}");
                        _ = AutoDownloadOriginalImageAsync(item);
                    }
                }
                else
                {
                    System.Diagnostics.Debug.WriteLine($"[MainVM] 条目 {item.Id} 已存在，跳过插入");
                }
            }
            else
            {
                System.Diagnostics.Debug.WriteLine("[MainVM] 无法解析新条目数据");
            }
            
            await Task.CompletedTask;
        }

        public async Task InitializeAsync(string token)
        {
            System.Diagnostics.Debug.WriteLine("[MainVM] 正在启动初始化流程 InitializeAsync...");
            _apiService.SetToken(token);
            _remoteSync.SetToken(token);
            
            // 0. 加载本地设置 (包括热键)
            var settings = await _dataStore.LoadWindowSettingsAsync();
            if (settings != null)
            {
                if (!string.IsNullOrEmpty(settings.Hotkey))
                {
                    _currentHotkey = settings.Hotkey;
                    OnPropertyChanged(nameof(CurrentHotkey));
                }
                _hideAfterPaste = settings.HideAfterPaste;
                OnPropertyChanged(nameof(HideAfterPaste));
            }

            // 1. 获取用户信息
            _ = FetchUserInfoAsync();

            // 2. 核心数据拉取 (必须执行)
            System.Diagnostics.Debug.WriteLine("[MainVM] 正在拉取首屏 All 项目...");
            await FetchItemsAsync(1);

            // 3. 加载分类列表
            _ = FetchCategoriesAsync();

            // 4. 建立实时连接
            _ = InitializeRealtimeAsync();

            // 5. 计算草稿数
            _ = UpdateDraftCountAsync();
            
            System.Diagnostics.Debug.WriteLine("[MainVM] InitializeAsync 流程执行完毕");
        }

        private async Task UpdateDraftCountAsync()
        {
            var localItems = await _dataStore.LoadAsync();
            DraftCount = localItems.Count(i => i.UploadFailed);
        }

        private async Task ClearAllDraftsAsync()
        {
            var localItems = (await _dataStore.LoadAsync()).ToList();
            // 移除所有失败的草稿
            var drafts = localItems.Where(i => i.UploadFailed).ToList();
            foreach (var draft in drafts)
            {
                localItems.Remove(draft);
            }
            await _dataStore.SaveAsync(localItems);
            
            // 如果当前在草稿箱，清空显示
            if (SelectedCategory == "drafts")
            {
                Items.Clear();
            }
            
            await UpdateDraftCountAsync();
            System.Diagnostics.Debug.WriteLine($"[MainVM] Cleared {drafts.Count} drafts");
        }

        private async Task FetchUserInfoAsync()
        {
            try
            {
                var userInfo = await _apiService.GetAsync<Dictionary<string, object>>("/auth/me");
                if (userInfo != null && userInfo.ContainsKey("email"))
                {
                    UserEmail = userInfo["email"].ToString() ?? string.Empty;
                    System.Diagnostics.Debug.WriteLine($"[MainVM] Current user: {UserEmail}");
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 获取用户信息失败: {ex.Message}");
            }
        }

        public async Task FetchCategoriesAsync()
        {
            try
            {
                // 刷新前先清空现有分类
                Categories.Clear();
                
                var categories = await _apiService.GetAsync<List<Category>>("/categories");
                if (categories != null)
                {
                    foreach (var cat in categories)
                    {
                        Categories.Add(cat);
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 获取分类失败: {ex.Message}");
            }
        }

        private async Task CreateCategoryAsync(string name)
        {
            try
            {
                var result = await _apiService.PostAsync<Category>("/categories", new { name });
                if (result != null)
                {
                    await FetchCategoriesAsync();
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 创建分类异常: {ex.Message}");
            }
        }

        private async Task UpdateCategoryAsync(string id, string newName)
        {
            System.Diagnostics.Debug.WriteLine($"[MainVM] 发起更新分类名称: ID={id}, NewName={newName}");
            try
            {
                // 根据后端 API 习惯，有些后端可能接受 PUT /categories/{id} 带 { name: "..." }
                var result = await _apiService.PutAsync<Category>($"/categories/{id}", new { name = newName });
                if (result != null)
                {
                    System.Diagnostics.Debug.WriteLine($"[MainVM] 分类名称更新成功: {id}");
                    await FetchCategoriesAsync();
                }
                else
                {
                    // 尝试 PATCH 兜底，万一后端只支持增量更新
                    System.Diagnostics.Debug.WriteLine($"[MainVM] PUT 更新返回空，尝试 PATCH 兜底...");
                    var patchResult = await _apiService.PatchAsync<Category>($"/categories/{id}", new { name = newName });
                    if (patchResult != null)
                    {
                        System.Diagnostics.Debug.WriteLine($"[MainVM] PATCH 更新成功: {id}");
                        await FetchCategoriesAsync();
                    }
                    else
                    {
                        System.Diagnostics.Debug.WriteLine($"[MainVM] 分类名称更新失败: {id}");
                        MessageBox.Show("Failed to rename category. Please check if the name already exists.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 更新分类异常: {ex.Message}");
                MessageBox.Show($"Rename error: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private async Task DeleteCategoryAsync(string id)
        {
            try
            {
                bool success = await _apiService.DeleteAsync($"/categories/{id}");
                if (success)
                {
                    if (SelectedCategory != "all" && SelectedCategory != "bookmarked" && SelectedCategory != "drafts")
                    {
                        var deletedCat = Categories.FirstOrDefault(c => c.Id == id);
                        if (deletedCat != null && SelectedCategory == deletedCat.Name)
                        {
                            SelectedCategory = "all";
                            await FetchItemsAsync(1);
                        }
                    }
                    await FetchCategoriesAsync();
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 删除分类异常: {ex.Message}");
            }
        }

        private async Task AddItemToCategoryAsync(string categoryId, string itemId)
        {
            try
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 正在将项目 {itemId} 添加到分类 {categoryId}");
                var success = await _apiService.PostAsync<Dictionary<string, object>>($"/categories/{categoryId}/items/{itemId}", new { });
                if (success != null)
                {
                    System.Diagnostics.Debug.WriteLine("[MainVM] 添加到分类成功");
                    await FetchCategoriesAsync(); // 刷新计数
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 添加到分类异常: {ex.Message}");
            }
        }

        public async Task FetchItemsAsync(int page)
        {
            if (IsLoading) return;
            
            System.Diagnostics.Debug.WriteLine($"[MainVM] 开始 FetchItems: page={page}, category={_selectedCategory}, search={SearchText}");
            
            _fetchCts?.Cancel();
            _fetchCts = new System.Threading.CancellationTokenSource();
            
            // 根据请求类型设置加载文案
            if (page == 1)
            {
                LoadingText = !string.IsNullOrWhiteSpace(SearchText) ? "Searching..." : "Loading...";
            }
            else
            {
                LoadingText = "Loading more...";
            }

            IsLoading = true;
            try
            {
                // 关键修复：只要是请求第一页（包括搜索和刷新），立即在发起网络请求前清空列表
                if (page == 1)
                {
                    System.Windows.Application.Current.Dispatcher.Invoke(() => Items.Clear());
                }

                if (_selectedCategory == "drafts")
                {
                    // 加载本地草稿逻辑
                    if (page == 1)
                    {
                        var localItems = await _dataStore.LoadAsync();
                        var drafts = localItems.Where(i => i.UploadFailed).OrderByDescending(i => i.CreatedAt);
                        foreach (var draft in drafts)
                        {
                            if (string.IsNullOrEmpty(SearchText) || 
                                (draft.Content != null && draft.Content.Contains(SearchText, StringComparison.OrdinalIgnoreCase)))
                            {
                                draft.InitializeImageState();
                                Items.Add(draft);
                            }
                        }
                        _currentPage = 1;
                        _hasMore = false;
                    }
                    return;
                }

                var queryParams = new List<string>();
                queryParams.Add($"page={page}");
                queryParams.Add($"page_size={DefaultPageSize}");

                if (!string.IsNullOrWhiteSpace(SearchText))
                {
                    // 有搜索时忽略分类/收藏过滤，只按搜索匹配
                    queryParams.Add($"search={Uri.EscapeDataString(SearchText)}");
                }
                else
                {
                    if (_selectedCategory == "bookmarked") queryParams.Add("bookmarked_only=true");
                    else if (_selectedCategory != "all") queryParams.Add($"category={Uri.EscapeDataString(_selectedCategory)}");
                }

                var url = $"/clipboard/items?{string.Join("&", queryParams)}";
                var remoteItems = await _apiService.GetAsync<List<ClipboardEntry>>(url, _fetchCts.Token);

                if (remoteItems != null)
                {
                    System.Diagnostics.Debug.WriteLine($"[MainVM] 成功从服务器获取 {remoteItems.Count} 条数据");

                    foreach (var item in remoteItems)
                    {
                        var existing = Items.FirstOrDefault(i => i.Id == item.Id);
                        if (existing == null)
                        {
                            item.InitializeImageState();
                            Items.Add(item);
                            
                            if (item.ContentType == "image" && item.IsThumbnail && !item.OriginalDeleted)
                            {
                                _ = AutoDownloadOriginalImageAsync(item);
                            }
                        }
                        else
                        {
                            existing.IsBookmarked = item.IsBookmarked;
                            existing.Content = item.Content;
                        }
                    }

                    _currentPage = page;
                    _hasMore = remoteItems.Count == DefaultPageSize;
                    LoadMoreCommand.RaiseCanExecuteChanged();
                }
                else if (page == 1)
                {
                    System.Diagnostics.Debug.WriteLine("[MainVM] 服务器返回空或失败，回退到本地缓存");
                    var localItems = await _dataStore.LoadAsync();
                    foreach (var item in localItems.OrderByDescending(i => i.CreatedAt))
                    {
                        item.InitializeImageState();
                        Items.Add(item);
                    }
                }
            }
            finally
            {
                IsLoading = false;
                System.Diagnostics.Debug.WriteLine("[MainVM] FetchItems 结束");
            }
        }

        private Task SyncRemoteDataAsync()
        {
            // 此方法已被 FetchItemsAsync(1) 替代或整合
            return Task.CompletedTask;
        }

        private async Task InitializeRealtimeAsync(bool force = false)
        {
            var authService = new AuthService();
            var token = await authService.GetSavedTokenAsync();
            if (string.IsNullOrEmpty(token)) return;

            await _wsService.ConnectAsync(token, _deviceId, force);
        }

        private string _lastCapturedSignature = string.Empty;

        public async Task OnClipboardUpdatedAsync()
        {
            // 1. 忽略点击复制后 1 秒内的所有系统事件，防止循环触发或重复触发
            if (DateTimeOffset.Now - _lastCopyTime < TimeSpan.FromSeconds(1))
            {
                System.Diagnostics.Debug.WriteLine("[MainVM] 处于复制保护期，忽略剪贴板事件");
                return;
            }

            var entry = await TryCreateEntryFromClipboardAsync();
            if (entry == null) return;

            string currentSignature = BuildSignature(entry);

            // 2. 全局去重逻辑：如果当前内容指纹与上一次完全一致，则视为系统重复触发，直接拦截
            if (currentSignature == _lastCapturedSignature)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 检测到重复内容 ({entry.ContentType})，已拦截");
                return;
            }

            _lastCapturedSignature = currentSignature;

            entry.InitializeImageState();
            Items.Insert(0, entry);
            
            // 发起异步上传
            _ = PerformUploadAsync(entry);
        }

        private async Task PerformUploadAsync(ClipboardEntry entry)
        {
            entry.IsUploading = true;
            entry.UploadFailed = false;
            
            try
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 正在上传条目: {entry.Id}");
                var result = await _remoteSync.PushAsync(entry);
                
                if (result.Success)
                {
                    if (result.IsDuplicate)
                    {
                        // 服务器返回 409 重复，视为成功，不显示错误
                        System.Diagnostics.Debug.WriteLine($"[MainVM] 服务器判定重复，视为成功: {entry.Id}");
                        entry.IsUploading = false;
                        entry.UploadFailed = false;
                        await RemoveFromLocalDraftsAsync(entry);
                    }
                    else
                    {
                        System.Diagnostics.Debug.WriteLine($"[MainVM] 上传成功: {entry.Id}");
                        
                        // 上传成功，如果是在草稿箱中，需要从本地列表移除
                        if (SelectedCategory == "drafts")
                        {
                            Items.Remove(entry);
                        }
                        
                        // 从本地持久化存储中移除草稿标记并保存
                        entry.IsUploading = false;
                        entry.UploadFailed = false;
                        
                        // 如果 ID 发生了变化（后端分配了新 ID），则更新 ID
                        if (result.Item != null && entry.Id != result.Item.Id)
                        {
                            entry.Id = result.Item.Id;
                        }
                        
                        await RemoveFromLocalDraftsAsync(entry);
                    }
                }
                else
                {
                    System.Diagnostics.Debug.WriteLine($"[MainVM] 上传失败: {entry.Id}, 原因: {result.ErrorMessage}");
                    entry.UploadFailed = true;
                    await SaveToLocalDraftsAsync(entry);
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 上传异常: {ex.Message}");
                entry.UploadFailed = true;
                await SaveToLocalDraftsAsync(entry);
            }
            finally
            {
                entry.IsUploading = false;
                await UpdateDraftCountAsync();
            }
        }

        private async Task SaveToLocalDraftsAsync(ClipboardEntry entry)
        {
            var localItems = (await _dataStore.LoadAsync()).ToList();
            var existing = localItems.FirstOrDefault(i => i.Id == entry.Id);
            if (existing != null)
            {
                localItems.Remove(existing);
            }
            localItems.Add(entry);
            await _dataStore.SaveAsync(localItems);
        }

        private async Task RemoveFromLocalDraftsAsync(ClipboardEntry entry)
        {
            var localItems = (await _dataStore.LoadAsync()).ToList();
            var existing = localItems.FirstOrDefault(i => i.Id == entry.Id);
            if (existing != null)
            {
                localItems.Remove(existing);
                await _dataStore.SaveAsync(localItems);
            }
        }

        private async Task AutoDownloadOriginalImageAsync(ClipboardEntry item)
        {
            if (item.IsDownloadingOriginal) return;

            // 1. 检查本地缓存
            var cachedPath = _dataStore.GetCachedOriginalImagePath(item.Id);
            if (cachedPath != null)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 使用本地缓存原图: {item.Id}");
                item.DisplayImageData = cachedPath;
                item.IsThumbnail = false;
                return;
            }

            // 随机延迟 300-2000ms
            var random = new Random();
            await Task.Delay(random.Next(300, 2000));

            item.IsDownloadingOriginal = true;
            try
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 正在从服务器下载原图: {item.Id}");
                var result = await _apiService.GetAsync<Dictionary<string, string>>($"/clipboard/items/{item.Id}/original");
                if (result != null && result.TryGetValue("original_image", out var originalBase64))
                {
                    // 2. 将下载的原图存入本地缓存
                    var converter = new ImagePathConverter();
                    var bitmap = converter.Convert(originalBase64, typeof(BitmapSource), null, System.Globalization.CultureInfo.CurrentCulture) as BitmapSource;
                    
                    if (bitmap != null)
                    {
                        var localPath = await _dataStore.SaveOriginalImageAsync(item.Id, bitmap);
                        item.DisplayImageData = localPath;
                        item.IsThumbnail = false;
                        System.Diagnostics.Debug.WriteLine($"[MainVM] 原图下载并缓存成功: {item.Id}");
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 原图下载失败: {ex.Message}");
            }
            finally
            {
                item.IsDownloadingOriginal = false;
            }
        }

        public async Task<bool> UpdateEntryTextAsync(ClipboardEntry entry, string newText)
        {
            if (entry.ContentType != "text" && entry.ContentType != "url") return false;
            
            System.Diagnostics.Debug.WriteLine($"[MainVM] 正在更新条目内容: {entry.Id}");
            try
            {
                // 1. 调用 PATCH 接口
                var result = await _apiService.PatchAsync<ClipboardEntry>($"/clipboard/items/{entry.Id}/content", new { content = newText });
                
                if (result != null)
                {
                    // 2. 更新本地状态
                    entry.UpdateText(newText);
                    await PersistAsync();
                    System.Diagnostics.Debug.WriteLine($"[MainVM] 内容更新成功: {entry.Id}");
                    return true;
                }
                
                MessageBox.Show("Failed to update content. Please try again.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                return false;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 内容更新异常: {ex.Message}");
                MessageBox.Show($"Update error: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                return false;
            }
        }

        public void AddManualEntryAsync(ClipboardEntry entry)
        {
            Items.Insert(0, entry);
            _ = PersistAsync();
        }

        private async Task ToggleBookmarkAsync(ClipboardEntry entry)
        {
            bool newStatus = !entry.IsBookmarked;
            System.Diagnostics.Debug.WriteLine($"[MainVM] 发起收藏切换: ID={entry.Id}, NewStatus={newStatus}");
            
            try
            {
                // 1. 乐观更新 UI
                entry.IsBookmarked = newStatus;

                // 2. 调用后端接口 (注意：这里应该使用 PATCH)
                var result = await _apiService.PatchAsync<Dictionary<string, object>>($"/clipboard/items/{entry.Id}/bookmark", new { is_bookmarked = newStatus });
                
                if (result != null)
                {
                    System.Diagnostics.Debug.WriteLine($"[MainVM] 收藏同步成功: {entry.Id}");
                    await PersistAsync();
                }
                else
                {
                    System.Diagnostics.Debug.WriteLine($"[MainVM] 收藏同步失败 (服务器未返回对象)，回滚状态: {entry.Id}");
                    entry.IsBookmarked = !newStatus;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 收藏请求异常: {ex.Message}");
                entry.IsBookmarked = !newStatus;
            }
        }

        private async Task<ClipboardEntry?> TryCreateEntryFromClipboardAsync()
        {
            try
            {
                // 剪贴板必须在 UI 线程访问
                return await Application.Current.Dispatcher.Invoke(async () =>
                {
                    if (System.Windows.Clipboard.ContainsText())
                    {
                        var text = System.Windows.Clipboard.GetText();
                        if (string.IsNullOrWhiteSpace(text)) return null;

                        return new ClipboardEntry
                        {
                            ContentType = "text",
                            Content = text.Trim(),
                            CreatedAt = DateTimeOffset.Now
                        };
                    }

                    if (System.Windows.Clipboard.ContainsImage())
                    {
                        var image = System.Windows.Clipboard.GetImage();
                        if (image == null) return null;

                        return await CreateImageEntryAsync(image);
                    }

                    return null;
                });
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 采集剪贴板异常: {ex.Message}");
                return null;
            }
        }

        private async Task<ClipboardEntry> CreateImageEntryAsync(BitmapSource image)
        {
            var path = await _dataStore.SaveImageAsync(image);
            return new ClipboardEntry
            {
                ContentType = "image",
                Thumbnail = path, // 本地采集时，路径存在 Thumbnail 中
                CreatedAt = DateTimeOffset.Now
            };
        }

        private async Task PersistAsync()
        {
            await _dataStore.SaveAsync(Items);
        }

        private async Task DeleteEntryAsync(ClipboardEntry entry)
        {
            System.Diagnostics.Debug.WriteLine($"[MainVM] 准备删除条目: {entry.Id}, UploadFailed: {entry.UploadFailed}");

            // 1. 确认逻辑 (使用统一 UI 的 ConfirmWindow)
            var activeWindow = GetActiveWindow();
            var dialog = new Pastee.App.Views.ConfirmWindow("Are you sure you want to delete this item?")
            {
                Owner = activeWindow
            };
            
            if (dialog.ShowDialog() != true) return;

            try
            {
                // 如果是上传失败的草稿，只需要从本地删除
                if (entry.UploadFailed)
                {
                    System.Diagnostics.Debug.WriteLine($"[MainVM] 删除本地草稿: {entry.Id}");
                    Items.Remove(entry);
                    await RemoveFromLocalDraftsAsync(entry);
                    await UpdateDraftCountAsync();
                    return;
                }

                // 2. 调用后端 API
                bool success = await _apiService.DeleteAsync($"/clipboard/items/{entry.Id}");

                if (success)
                {
                    System.Diagnostics.Debug.WriteLine($"[MainVM] 后端删除成功: {entry.Id}");
                    // 3. 本地移除
                    Items.Remove(entry);
                    await PersistAsync();
                    
                    // 如果在草稿箱模式，同步更新计数
                    if (SelectedCategory == "drafts")
                    {
                        await UpdateDraftCountAsync();
                    }
                }
                else
                {
                    System.Diagnostics.Debug.WriteLine($"[MainVM] 后端删除失败: {entry.Id}");
                    MessageBox.Show(activeWindow ?? Application.Current.MainWindow, 
                        "Failed to delete item from server. Please try again.", "Error", 
                        MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 删除异常: {ex.Message}");
                MessageBox.Show(activeWindow ?? Application.Current.MainWindow, 
                    $"Delete error: {ex.Message}", "Error", 
                    MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void DeleteEntry(ClipboardEntry entry)
        {
            // 此同步方法已废弃，改用 DeleteEntryAsync
            _ = DeleteEntryAsync(entry);
        }

        private bool FilterItem(object obj)
        {
            var entry = obj as ClipboardEntry;
            if (entry == null) return false;
            if (string.IsNullOrWhiteSpace(SearchText)) return true;
            if (entry.Content != null && entry.Content.IndexOf(SearchText, StringComparison.OrdinalIgnoreCase) >= 0)
                return true;
            if (entry.ContentType == "image" && entry.FileName != null && entry.FileName.IndexOf(SearchText, StringComparison.OrdinalIgnoreCase) >= 0)
                return true;
            return false;
        }

        private static string BuildSignature(ClipboardEntry entry)
        {
            if (entry.ContentType == "text")
            {
                return string.Format("{0}:{1}", "text", entry.Content == null ? string.Empty : entry.Content.Trim());
            }

            if (entry.ContentType == "image")
            {
                // 如果有本地存储路径，使用路径作为指纹（采集瞬间生成的路径是唯一的，但系统多次触发时路径相同）
                // 如果是刚从剪贴板抓取的，路径存在 Thumbnail 中
                var path = entry.Thumbnail ?? entry.FilePath;
                if (!string.IsNullOrEmpty(path) && File.Exists(path))
                {
                    try
                    {
                        // 真正的文件内容校验：使用文件大小 + 修改时间作为快速指纹，或者读取前 1KB
                        var fi = new FileInfo(path);
                        return string.Format("image:{0}:{1}", fi.Length, fi.LastWriteTimeUtc.Ticks);
                    }
                    catch { }
                }
                return string.Format("{0}:{1}", "image", path);
            }

            return Guid.NewGuid().ToString();
        }

        private async Task CopyEntryToClipboardAsync(ClipboardEntry entry)
        {
            try
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 正在执行复制逻辑: {entry.Id}");
                
                // 1. 记录点击复制时间，开启 1 秒保护期
                _lastCopyTime = DateTimeOffset.Now;

                // 2. 执行复制操作
                if (entry.ContentType == "text" || entry.ContentType == "url")
                {
                    if (!string.IsNullOrEmpty(entry.Content))
                    {
                        System.Windows.Clipboard.SetText(entry.Content);
                    }
                    System.Diagnostics.Debug.WriteLine($"[MainVM] 文本已复制，原地保留: {entry.Id}");
                    ItemCopied?.Invoke(this, EventArgs.Empty);
                }
                else if (entry.ContentType == "image")
                {
                    var imageSource = entry.DisplayImageData;
                    var converter = new ImagePathConverter();
                    var bitmap = converter.Convert(imageSource, typeof(BitmapSource), null, System.Globalization.CultureInfo.CurrentCulture) as BitmapSource;
                    if (bitmap != null)
                    {
                        System.Windows.Clipboard.SetImage(bitmap);
                    }
                    System.Diagnostics.Debug.WriteLine($"[MainVM] 图片已复制，原地保留: {entry.Id}");
                    ItemCopied?.Invoke(this, EventArgs.Empty);
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 复制逻辑异常: {ex.Message}");
            }
        }

        private async Task DeleteEntryFromServerOnlyAsync(ClipboardEntry entry)
        {
            try
            {
                await _apiService.DeleteAsync($"/clipboard/items/{entry.Id}");
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MainVM] 仅服务器删除失败: {ex.Message}");
            }
        }

        private void CopyEntryToClipboard(ClipboardEntry entry)
        {
            // 改为异步执行复制和删除逻辑
            _ = CopyEntryToClipboardAsync(entry);
        }

        private Window? GetActiveWindow()
        {
            foreach (Window window in Application.Current.Windows)
            {
                if (window.IsVisible && !(window is MainWindow))
                {
                    return window;
                }
            }
            return Application.Current.MainWindow;
        }

        private void OnPropertyChanged(string propertyName)
        {
            var handler = PropertyChanged;
            if (handler != null)
            {
                handler(this, new PropertyChangedEventArgs(propertyName));
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        public event EventHandler<ClipboardEntry>? RequestEdit;
        public event EventHandler? ItemCopied;
    }
}
