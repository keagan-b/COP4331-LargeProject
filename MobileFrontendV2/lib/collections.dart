import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'login.dart' show AppBackground, AppColors, LoginPage;
import 'categories.dart' show Category;
import 'dialog_helpers.dart';
import 'items.dart';
import 'services/api_service.dart';

class CollectionModel {
  final String id;
  final String name;
  CollectionModel({required this.id, required this.name});
  factory CollectionModel.fromJson(Map<String, dynamic> j) =>
      CollectionModel(id: j['_id'], name: j['collectionName']);
}

class CollectionsPage extends StatefulWidget {
  final Category category;
  const CollectionsPage({super.key, required this.category});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  List<CollectionModel> _collections = [];
  List<ItemModel> _items = [];
  List<CriterionModel> _criteria = [];
  bool _loading = true;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _searchField = 'Item Name';

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── API ──────────────────────────────────────────────────────────────
  Future<void> _fetchAll() async {
    await Future.wait([_fetchCollections(), _fetchCriteria()]);
    await _fetchItems();
    setState(() => _loading = false);
  }

  Future<void> _fetchCollections() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/collections?categoryId=${widget.category.id}'),
        headers: {'token': ApiService.sessionToken ?? ''},
      );
      final data = jsonDecode(res.body);
      _collections = (data['collections'] as List)
          .map((e) => CollectionModel.fromJson(e))
          .toList();
    } catch (_) {}
  }

  Future<void> _fetchCriteria() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/categories/criteria?categoryId=${widget.category.id}'),
        headers: {'token': ApiService.sessionToken ?? ''},
      );
      final data = jsonDecode(res.body);
      _criteria = (data['criteria'] as List)
          .map((e) => CriterionModel.fromJson(e))
          .toList();
    } catch (_) {}
  }

  Future<void> _fetchItems() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/categories/items?categoryId=${widget.category.id}'),
        headers: {'token': ApiService.sessionToken ?? ''},
      );
      final data = jsonDecode(res.body);
      final raw = (data['items'] as List? ?? []).cast<Map<String, dynamic>>();
      _items = raw.map((item) {
        final cv = item['criteriaValues'];
        final Map<String, String> values = {};
        if (cv is Map) cv.forEach((k, v) { if (k != null && v != null) values[k.toString()] = v.toString(); });
        final rawItem = Map<String, dynamic>.from(item);
        rawItem['imageUrl'] ??= item['image_url'] ?? item['ImageUrl'] ?? item['image'];
        return ItemModel.fromJson(rawItem, values);
      }).toList();
    } catch (_) {}
  }

  Future<void> _addCollection(String name) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/collections'),
        headers: {'Content-Type': 'application/json', 'token': ApiService.sessionToken ?? ''},
        body: jsonEncode({'collectionName': name, 'categoryId': widget.category.id}),
      );
      final data = jsonDecode(res.body);
      setState(() => _collections.add(CollectionModel(id: data['id'], name: data['collectionName'])));
    } catch (_) {}
  }

  Future<void> _editCollection(String id, String newName) async {
    try {
      await http.patch(
        Uri.parse('${ApiService.baseUrl}/api/collections'),
        headers: {'Content-Type': 'application/json', 'token': ApiService.sessionToken ?? ''},
        body: jsonEncode({'collectionId': id, 'collectionName': newName}),
      );
      setState(() {
        _collections = _collections
            .map((c) => c.id == id ? CollectionModel(id: id, name: newName) : c)
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _deleteCollection(String id) async {
    try {
      await http.delete(
        Uri.parse('${ApiService.baseUrl}/api/collections'),
        headers: {'Content-Type': 'application/json', 'token': ApiService.sessionToken ?? ''},
        body: jsonEncode({'collectionId': id}),
      );
      setState(() => _collections.removeWhere((c) => c.id == id));
    } catch (_) {}
  }

  void _logout() {
    ApiService.sessionToken = null;
    Navigator.pushAndRemoveUntil(
      context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  // ── Filtering ────────────────────────────────────────────────────────
  List<ItemModel> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    final q = _searchQuery.toLowerCase();
    return _items.where((item) {
      if (_searchField == 'Item Name') return item.name.toLowerCase().contains(q);
      return (item.criteriaValues[_searchField] ?? '').toLowerCase().contains(q);
    }).toList();
  }

  // ── Dialogs ──────────────────────────────────────────────────────────
  void _showAddCollectionDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.accentBorder, width: 1),
        ),
        title: const Text('New Collection',
            style: TextStyle(color: AppColors.textPrimary, fontFamily: 'SquadaOne', fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            dlgLabel('Collection Name'),
            dlgTextField(ctrl, 'e.g. Favorites'),
          ],
        ),
        actions: [
          dlgCancelBtn(ctx),
          dlgConfirmBtn('Create', () {
            final name = ctrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx);
            _addCollection(name);
          }),
        ],
      ),
    );
  }

  void _showCollectionOptions(CollectionModel col) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgRaised,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.accentBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Text(col.name, style: const TextStyle(
                color: AppColors.textPrimary, fontFamily: 'SquadaOne',
                fontSize: 16, fontWeight: FontWeight.w700)),
            const Divider(color: AppColors.borderSubtle),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.accent),
              title: const Text('Edit', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'SquadaOne')),
              onTap: () {
                Navigator.pop(context);
                _showEditCollectionDialog(col);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.red),
              title: const Text('Delete', style: TextStyle(color: AppColors.red, fontFamily: 'SquadaOne')),
              onTap: () {
                Navigator.pop(context);
                _showDeleteCollectionDialog(col);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCollectionDialog(CollectionModel col) {
    final ctrl = TextEditingController(text: col.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.accentBorder, width: 1),
        ),
        title: const Text('Edit Collection',
            style: TextStyle(color: AppColors.textPrimary, fontFamily: 'SquadaOne', fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [dlgLabel('Collection Name'), dlgTextField(ctrl, '')],
        ),
        actions: [
          dlgCancelBtn(ctx),
          dlgConfirmBtn('Save', () {
            final name = ctrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx);
            _editCollection(col.id, name);
          }),
        ],
      ),
    );
  }

  void _showDeleteCollectionDialog(CollectionModel col) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.accentBorder, width: 1),
        ),
        title: const Text('Delete Collection',
            style: TextStyle(color: AppColors.textPrimary, fontFamily: 'SquadaOne', fontSize: 18)),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: AppColors.textMuted, fontFamily: 'SquadaOne', fontSize: 14),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(text: '"${col.name}"', style: const TextStyle(color: AppColors.textPrimary)),
              const TextSpan(text: '? This cannot be undone.'),
            ],
          ),
        ),
        actions: [
          dlgCancelBtn(ctx),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _deleteCollection(col.id); },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.red, fontFamily: 'SquadaOne', fontWeight: FontWeight.w700)),
          ),
        ],
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
              buildBreadcrumb([
                BreadcrumbItem(
                  label: 'Home',
                  onTap: () => Navigator.pop(context),
                ),
                BreadcrumbItem(label: widget.category.name),
              ]),

              // Collections horizontal chip bar
              if (!_loading)
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      // Add collection chip
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton(
                          onPressed: _showAddCollectionDialog,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.accentBorder),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            backgroundColor: AppColors.accentDim,
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add, color: AppColors.accent, size: 16),
                              SizedBox(width: 4),
                              Text('Add', style: TextStyle(color: AppColors.accent,
                                  fontFamily: 'SquadaOne', fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                      // Existing collections
                      ..._collections.map((col) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onLongPress: () => _showCollectionOptions(col),
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ItemsPage(
                                category: widget.category,
                                collection: col,
                                allCollections: _collections,
                                criteria: _criteria,
                              )),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              elevation: 0,
                            ),
                            child: Text(col.name,
                                style: const TextStyle(fontFamily: 'SquadaOne', fontSize: 13)),
                          ),
                        ),
                      )),
                    ],
                  ),
                ),

              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    // Search field dropdown
                    Container(
                      height: 42,
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
                          items: ['Item Name', ..._criteria.map((c) => c.name)]
                              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() {
                              _searchField = val;
                              _searchQuery = '';
                              _searchCtrl.clear();
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search by $_searchField…',
                            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                            filled: true,
                            fillColor: AppColors.bgCard,
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
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 16),
                                    onPressed: () => setState(() {
                                      _searchQuery = ''; _searchCtrl.clear();
                                    }))
                                : const Icon(Icons.search, color: AppColors.textMuted, size: 18),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Items grid
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                    : _filteredItems.isEmpty
                        ? Center(
                            child: Text(
                              _items.isEmpty ? 'No items yet.' : 'No items match your search.',
                              style: const TextStyle(color: AppColors.textMuted,
                                  fontFamily: 'SquadaOne', fontSize: 15),
                            ))
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.72,
                            ),
                            itemCount: _filteredItems.length,
                            itemBuilder: (_, i) => _buildItemCard(_filteredItems[i]),
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
          const Expanded(
            child: Text("Collector's Pair-A-Dice",
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18,
                    fontFamily: 'SquadaOne', letterSpacing: 0.6)),
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

  Widget _buildItemCard(ItemModel item) {
    return GestureDetector(
      onTap: () async {
        final col = _collections.firstWhere(
          (c) => c.id == item.collectionId,
          orElse: () => _collections.isNotEmpty
              ? _collections.first
              : CollectionModel(id: '', name: ''),
        );
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ItemEditPage(
            item: item, criteria: _criteria,
            category: widget.category, collection: col,
          )),
        );
        setState(() => _loading = true);
        await _fetchItems();
        setState(() => _loading = false);
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
                      color: AppColors.textSecondary,
                      fontFamily: 'SquadaOne',
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
