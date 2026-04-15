import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'login.dart' show AppBackground, AppColors, webCard, WebButton, LoginPage;
import 'categories.dart' show Category;
import 'dialog_helpers.dart';
import 'collections.dart';
import 'services/api_service.dart';

// ─── Models ───────────────────────────────────────────────────────────────
class CriterionModel {
  final String id;
  final String name;
  CriterionModel({required this.id, required this.name});
  factory CriterionModel.fromJson(Map<String, dynamic> j) =>
      CriterionModel(id: j['_id'], name: j['criteriaName']);
}

class ItemModel {
  final String id;
  final String name;
  final String categoryId;
  final String? collectionId;
  final String? imageUrl;
  final Map<String, String> criteriaValues;

  ItemModel({
    required this.id,
    required this.name,
    required this.categoryId,
    this.collectionId,
    this.imageUrl,
    required this.criteriaValues,
  });

  factory ItemModel.fromJson(Map<String, dynamic> j, Map<String, String> values) => ItemModel(
        id: j['_id'],
        name: j['itemName'],
        categoryId: j['categoryId'] ?? '',
        collectionId: j['collectionId']?.toString(),
        imageUrl: j['imageUrl'],
        criteriaValues: values,
      );

  ItemModel copyWith({String? name, Map<String, String>? criteriaValues, String? imageUrl}) =>
      ItemModel(
        id: id, name: name ?? this.name,
        categoryId: categoryId, collectionId: collectionId,
        imageUrl: imageUrl ?? this.imageUrl,
        criteriaValues: criteriaValues ?? this.criteriaValues,
      );
}

// ─── Items Page ───────────────────────────────────────────────────────────
class ItemsPage extends StatefulWidget {
  final Category category;
  final CollectionModel collection;
  final List<CollectionModel> allCollections;
  final List<CriterionModel> criteria;

  const ItemsPage({
    super.key,
    required this.category,
    required this.collection,
    required this.allCollections,
    required this.criteria,
  });

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  List<ItemModel> _items = [];
  bool _loading = true;

  late String _sortCriteria;
  bool _sortAsc = true;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _searchField = 'Item Name';

  // Image picking
  final _picker = ImagePicker();
  XFile? _addDialogPickedImage;
  bool _addDialogUploadingImage = false;
  String? _dialogImageUrl;

  @override
  void initState() {
    super.initState();
    _sortCriteria = '__name__';
    _fetchItems();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── API ──────────────────────────────────────────────────────────────
  Future<void> _fetchItems() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/categories/items?categoryId=${widget.category.id}'),
        headers: {'token': ApiService.sessionToken ?? ''},
      );
      final data = jsonDecode(res.body);
      final raw = (data['items'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .where((item) => item['collectionId']?.toString() == widget.collection.id)
          .toList();

      final items = raw.map((item) {
        final cv = item['criteriaValues'];
        final Map<String, String> values = {};
        if (cv is Map) cv.forEach((k, v) {
          if (k != null && v != null) values[k.toString()] = v.toString();
        });
        final rawItem = Map<String, dynamic>.from(item);
        rawItem['imageUrl'] ??= item['image_url'] ?? item['ImageUrl'] ?? item['image'];
        return ItemModel.fromJson(rawItem, values);
      }).toList();

      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addItem(String name, Map<String, String> criteriaValues, {String? imageUrl}) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/items'),
        headers: {'Content-Type': 'application/json', 'token': ApiService.sessionToken ?? ''},
        body: jsonEncode({
          'itemName': name,
          'categoryId': widget.category.id,
          'collectionId': widget.collection.id,
          'criteriaValues': criteriaValues,
          if (imageUrl != null) 'imageUrl': imageUrl,
        }),
      );
      final data = jsonDecode(res.body);
      setState(() => _items.add(ItemModel(
        id: data['_id'], name: data['itemName'],
        categoryId: widget.category.id,
        collectionId: widget.collection.id,
        imageUrl: imageUrl,
        criteriaValues: criteriaValues,
      )));
    } catch (_) {}
  }

  void _logout() {
    ApiService.sessionToken = null;
    Navigator.pushAndRemoveUntil(
      context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  // ── Image Handling (Add Dialog) ──────────────────────────────────────
  void _showAddItemImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgRaised,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.accent),
                title: const Text('Camera',
                    style: TextStyle(color: AppColors.textPrimary, fontFamily: 'SquadaOne')),
                onTap: () { Navigator.pop(context); _pickAddItemImage(ImageSource.camera); },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: AppColors.accent),
                title: const Text('Gallery',
                    style: TextStyle(color: AppColors.textPrimary, fontFamily: 'SquadaOne')),
                onTap: () { Navigator.pop(context); _pickAddItemImage(ImageSource.gallery); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAddItemImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
      if (picked == null) return;
      setState(() { _addDialogPickedImage = picked; _addDialogUploadingImage = true; });
      await _uploadAddItemImage(picked);
    } catch (_) {
      if (!mounted) return;
      setState(() => _addDialogUploadingImage = false);
    }
  }

  Future<void> _uploadAddItemImage(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final request = http.MultipartRequest(
        'POST', Uri.parse('${ApiService.baseUrl}/api/upload-image'),
      )
        ..headers['token'] = ApiService.sessionToken ?? ''
        ..files.add(http.MultipartFile.fromBytes(
          'image', bytes, filename: file.name,
          contentType: http.MediaType.parse(mimeType),
        ));

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        setState(() {
          _dialogImageUrl = data['url'] as String?;
          _addDialogPickedImage = null;
          _addDialogUploadingImage = false;
        });
      } else {
        setState(() => _addDialogUploadingImage = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _addDialogUploadingImage = false);
    }
  }

  // ── Sort / Search ────────────────────────────────────────────────────
  List<ItemModel> get _sortedItems {
    final list = List<ItemModel>.from(_items);
    if (_sortCriteria == '__name__') {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      list.sort((a, b) =>
          (a.criteriaValues[_sortCriteria] ?? '').toLowerCase()
              .compareTo((b.criteriaValues[_sortCriteria] ?? '').toLowerCase()));
    }
    return _sortAsc ? list : list.reversed.toList();
  }

  List<ItemModel> get _filteredItems {
    final base = _sortedItems;
    if (_searchQuery.isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base.where((item) {
      if (_searchField == 'Item Name') return item.name.toLowerCase().contains(q);
      return (item.criteriaValues[_searchField] ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _onSortTap(String field) {
    setState(() {
      if (_sortCriteria == field) { _sortAsc = !_sortAsc; }
      else { _sortCriteria = field; _sortAsc = true; }
    });
  }

  // ── Add Item Dialog ──────────────────────────────────────────────────
  void _showAddItemDialog() {
    _dialogImageUrl = null;
    final nameCtrl = TextEditingController();
    final criteriaCtrl = <String, TextEditingController>{
      for (final c in widget.criteria) c.name: TextEditingController()
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppColors.bgRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.accentBorder, width: 1),
          ),
          title: const Text('New Item',
              style: TextStyle(color: AppColors.textPrimary, fontFamily: 'SquadaOne', fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image picker
                GestureDetector(
                  onTap: _addDialogUploadingImage ? null : _showAddItemImageSourceSheet,
                  child: Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accentBorder, width: 1),
                    ),
                    child: _addDialogUploadingImage
                        ? const Center(
                            child: CircularProgressIndicator(color: AppColors.accent),
                          )
                        : _addDialogPickedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Image.file(File(_addDialogPickedImage!.path),
                                    fit: BoxFit.cover, width: double.infinity),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined,
                                      color: AppColors.accentBorder, size: 40),
                                  SizedBox(height: 6),
                                  Text('Tap to add photo',
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontFamily: 'SquadaOne',
                                          fontSize: 12)),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 14),

                // Item name
                dlgLabel('Item Name'),
                dlgTextField(nameCtrl, 'Name'),

                // Criteria
                if (widget.criteria.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.borderSubtle),
                  ...widget.criteria.map((c) => Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        dlgLabel(c.name),
                        dlgTextField(criteriaCtrl[c.name]!, c.name),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
          actions: [
            dlgCancelBtn(ctx),
            TextButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final values = <String, String>{
                  for (final c in widget.criteria) c.name: criteriaCtrl[c.name]!.text.trim()
                };
                Navigator.pop(ctx);
                _addItem(name, values, imageUrl: _dialogImageUrl);
                _dialogImageUrl = null;
                _addDialogPickedImage = null;
              },
              child: const Text('Add',
                  style: TextStyle(
                      color: AppColors.accent, fontFamily: 'SquadaOne', fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Container(height: 1, color: AppColors.accentBorder),

              // Breadcrumb navigation
              buildBreadcrumb([
                BreadcrumbItem(
                  label: 'Home',
                  onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
                ),
                BreadcrumbItem(
                  label: widget.category.name,
                  onTap: () => Navigator.pop(context),
                ),
                BreadcrumbItem(label: widget.collection.name),
              ]),

              // Sort chips
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: [
                    _sortChip('Name', '__name__'),
                    ...widget.criteria.map((c) => _sortChip(c.name, c.name)),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accentBorder, width: 1),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _searchField,
                          dropdownColor: AppColors.bgRaised,
                          style: const TextStyle(color: AppColors.textPrimary,
                              fontFamily: 'SquadaOne', fontSize: 13),
                          iconEnabledColor: AppColors.accent,
                          items: ['Item Name', ...widget.criteria.map((c) => c.name)]
                              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() {
                              _searchField = val; _searchQuery = ''; _searchCtrl.clear();
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search by $_searchField…',
                            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                            filled: true, fillColor: AppColors.bgCard,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppColors.accentBorder, width: 1)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppColors.accentBorder, width: 1)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 16),
                                    onPressed: () => setState(() { _searchQuery = ''; _searchCtrl.clear(); }))
                                : const Icon(Icons.search, color: AppColors.textMuted, size: 18),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Grid
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: _filteredItems.length + 1,
                        itemBuilder: (_, i) {
                          if (i == 0) return _addCard();
                          return _itemCard(_filteredItems[i - 1]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Image.asset('assets/CPAD_Logo.png', height: 44, fit: BoxFit.contain),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.category.name,
                    style: const TextStyle(color: AppColors.textMuted,
                        fontSize: 11, fontFamily: 'SquadaOne', letterSpacing: 0.5)),
                Text(widget.collection.name,
                    style: const TextStyle(color: AppColors.textPrimary,
                        fontSize: 16, fontFamily: 'SquadaOne', fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          TextButton(
            onPressed: _logout,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.accentBorder, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Log Out',
                style: TextStyle(fontFamily: 'SquadaOne', fontSize: 13, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _sortChip(String label, String field) {
    final active = _sortCriteria == field;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _onSortTap(field),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.accent : AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: active ? AppColors.accent : AppColors.accentBorder, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      color: active ? Colors.white : AppColors.textSecondary,
                      fontFamily: 'SquadaOne', fontSize: 12, fontWeight: FontWeight.w700)),
              if (active) ...[
                const SizedBox(width: 4),
                Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 11, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _addCard() {
    return GestureDetector(
      onTap: _showAddItemDialog,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.accentBorder, width: 1, style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentDim,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentBorder, width: 1),
                ),
                child: const Icon(Icons.add, color: AppColors.accent, size: 24),
              ),
              const SizedBox(height: 8),
              const Text('Add Item',
                  style: TextStyle(color: AppColors.textMuted,
                      fontFamily: 'SquadaOne', fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemCard(ItemModel item) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ItemEditPage(
            item: item, criteria: widget.criteria,
            category: widget.category, collection: widget.collection,
          )),
        );
        await _fetchItems();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.accentBorder, width: 1),
        ),
        child: Column(
          children: [
            Expanded(
              child: item.imageUrl != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                      child: Image.network(item.imageUrl!,
                          fit: BoxFit.cover, width: double.infinity,
                          errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.image_outlined,
                                  color: AppColors.accentBorder, size: 40))),
                    )
                  : const Center(
                      child: Icon(Icons.image_outlined, color: AppColors.accentBorder, size: 40)),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: Color(0x58000000),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(9)),
                border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1)),
              ),
              child: Text(item.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontFamily: 'SquadaOne',
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Item Edit Page ───────────────────────────────────────────────────────
class ItemEditPage extends StatefulWidget {
  final ItemModel item;
  final List<CriterionModel> criteria;
  final Category category;
  final CollectionModel collection;

  const ItemEditPage({
    super.key,
    required this.item,
    required this.criteria,
    required this.category,
    required this.collection,
  });

  @override
  State<ItemEditPage> createState() => _ItemEditPageState();
}

class _ItemEditPageState extends State<ItemEditPage> {
  late TextEditingController _nameCtrl;
  late Map<String, TextEditingController> _criteriaCtrl;
  bool _saving = false;
  bool _showDeleteConfirm = false;
  XFile? _pickedImage;
  String? _currentImageUrl;
  bool _uploadingImage = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _currentImageUrl = widget.item.imageUrl;
    _criteriaCtrl = {
      for (final c in widget.criteria)
        c.name: TextEditingController(text: widget.item.criteriaValues[c.name] ?? '')
    };
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final ctrl in _criteriaCtrl.values) ctrl.dispose();
    super.dispose();
  }

  // ── Image ────────────────────────────────────────────────────────────
  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgRaised,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.accentBorder,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              const Text('Change Photo',
                  style: TextStyle(color: AppColors.textPrimary,
                      fontFamily: 'SquadaOne', fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
                title: const Text('Choose from Photos',
                    style: TextStyle(color: AppColors.textPrimary, fontFamily: 'SquadaOne')),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.accent),
                title: const Text('Take a Photo',
                    style: TextStyle(color: AppColors.textPrimary, fontFamily: 'SquadaOne')),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
      if (picked == null) return;
      setState(() { _pickedImage = picked; _uploadingImage = true; });
      await _uploadPickedImage(picked);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingImage = false);
    }
  }

  Future<void> _uploadPickedImage(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final request = http.MultipartRequest(
        'POST', Uri.parse('${ApiService.baseUrl}/api/upload-image'),
      )
        ..headers['token'] = ApiService.sessionToken ?? ''
        ..files.add(http.MultipartFile.fromBytes(
          'image', bytes, filename: file.name,
          contentType: http.MediaType.parse(mimeType),
        ));

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        setState(() {
          _currentImageUrl = data['url'] as String?;
          _pickedImage = null;
          _uploadingImage = false;
        });
      } else {
        setState(() => _uploadingImage = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingImage = false);
    }
  }

  // ── Save / Delete ────────────────────────────────────────────────────
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final values = <String, String>{
        for (final c in widget.criteria) c.name: _criteriaCtrl[c.name]!.text.trim()
      };
      await http.patch(
        Uri.parse('${ApiService.baseUrl}/api/items'),
        headers: {'Content-Type': 'application/json', 'token': ApiService.sessionToken ?? ''},
        body: jsonEncode({
          'itemId': widget.item.id,
          'itemName': name,
          'criteriaValues': values,
          if (_currentImageUrl != null) 'imageUrl': _currentImageUrl,
        }),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    try {
      await http.delete(
        Uri.parse('${ApiService.baseUrl}/api/items'),
        headers: {'Content-Type': 'application/json', 'token': ApiService.sessionToken ?? ''},
        body: jsonEncode({'itemId': widget.item.id}),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  void _logout() {
    ApiService.sessionToken = null;
    Navigator.pushAndRemoveUntil(
      context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  // ── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header with Back + Save
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Back
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 14, color: AppColors.accent),
                      label: const Text('Back',
                          style: TextStyle(color: AppColors.accent,
                              fontFamily: 'SquadaOne', fontSize: 14)),
                      style: TextButton.styleFrom(
                        side: const BorderSide(color: AppColors.accentBorder, width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const Spacer(),
                    // Save
                    _saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: AppColors.accent, strokeWidth: 2))
                        : TextButton(
                            onPressed: _save,
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            ),
                            child: const Text('Save',
                                style: TextStyle(fontFamily: 'SquadaOne',
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _logout,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.accentBorder, width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Log Out',
                          style: TextStyle(fontFamily: 'SquadaOne', fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: AppColors.accentBorder),

              // Breadcrumb navigation
              buildBreadcrumb([
                BreadcrumbItem(
                  label: 'Home',
                  onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
                ),
                BreadcrumbItem(
                  label: widget.category.name,
                  onTap: () => Navigator.pop(context),
                ),
                BreadcrumbItem(
                  label: widget.collection.name,
                  onTap: () => Navigator.pop(context),
                ),
                BreadcrumbItem(label: widget.item.name),
              ]),

              // Scrollable body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image section
                      _buildImageSection(),
                      const SizedBox(height: 16),

                      // Item name field
                      _buildLabel('Item Name'),
                      TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 15, fontFamily: 'SquadaOne',
                            fontWeight: FontWeight.w700),
                        decoration: _editInput('Item name'),
                      ),

                      // Criteria fields
                      if (widget.criteria.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ...widget.criteria.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 90,
                                child: Text('${c.name}:',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontFamily: 'SquadaOne',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _criteriaCtrl[c.name],
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                                  decoration: _editInput(''),
                                ),
                              ),
                            ],
                          ),
                        )),
                        const Divider(color: AppColors.borderSubtle),
                      ],

                      const SizedBox(height: 16),

                      // Delete
                      if (!_showDeleteConfirm)
                        GestureDetector(
                          onTap: () => setState(() => _showDeleteConfirm = true),
                          child: const Text('Delete Item',
                              style: TextStyle(
                                  color: AppColors.red,
                                  fontFamily: 'SquadaOne',
                                  fontSize: 15,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.red)),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Are you sure you want to delete "${widget.item.name}"?',
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontFamily: 'SquadaOne', fontSize: 13)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () => setState(() => _showDeleteConfirm = false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textSecondary,
                                    side: const BorderSide(color: AppColors.borderSubtle),
                                    shape: const StadiumBorder(),
                                  ),
                                  child: const Text('Cancel',
                                      style: TextStyle(fontFamily: 'SquadaOne', fontSize: 13)),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _saving ? null : _delete,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.red,
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                    elevation: 0,
                                  ),
                                  child: const Text('Confirm Delete',
                                      style: TextStyle(fontFamily: 'SquadaOne', fontSize: 13)),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    Widget content;
    if (_uploadingImage) {
      content = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            SizedBox(height: 10),
            Text('Uploading…',
                style: TextStyle(color: AppColors.textMuted,
                    fontFamily: 'SquadaOne', fontSize: 13)),
          ],
        ),
      );
    } else if (_pickedImage != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(_pickedImage!.path),
            fit: BoxFit.contain, width: double.infinity),
      );
    } else if (_currentImageUrl != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(_currentImageUrl!,
            fit: BoxFit.contain, width: double.infinity,
            errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: AppColors.accentBorder, size: 60))),
      );
    } else {
      content = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, color: AppColors.accentBorder, size: 56),
          SizedBox(height: 8),
          Text('Tap to add photo',
              style: TextStyle(color: AppColors.textMuted, fontFamily: 'SquadaOne', fontSize: 13)),
        ],
      );
    }

    return GestureDetector(
      onTap: _uploadingImage ? null : _showImageSourceSheet,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 180, maxHeight: 380),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.accentBorder, width: 1),
        ),
        child: Stack(
          children: [
            SizedBox(width: double.infinity, child: content),
            if (!_uploadingImage && (_pickedImage != null || _currentImageUrl != null))
              Positioned(
                bottom: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.edit_outlined, color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text.toUpperCase(),
        style: const TextStyle(
            color: AppColors.textMuted, fontSize: 10,
            fontWeight: FontWeight.w700, letterSpacing: 1.1,
            fontFamily: 'SquadaOne')),
  );

  InputDecoration _editInput(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
    filled: true,
    fillColor: const Color(0x990A0A19),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accentBorder, width: 1)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accentBorder, width: 1)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
  );
}
