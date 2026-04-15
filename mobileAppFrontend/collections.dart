import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'login.dart';
import 'categories.dart';
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

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _searchField = 'Item Name';

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  // ── API ────────────────────────────────────────────────────────────────────

  Future<void> _fetchAll() async {
    await Future.wait([_fetchCollections(), _fetchCriteria()]);
    await _fetchItems();
    setState(() => _loading = false);
  }

  Future<void> _fetchCollections() async {
    try {
      final res = await http.get(
        Uri.parse(
            '${ApiService.baseUrl}/api/collections?categoryId=${widget.category.id}'),
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
        Uri.parse(
            '${ApiService.baseUrl}/api/categories/criteria?categoryId=${widget.category.id}'),
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
        Uri.parse(
            '${ApiService.baseUrl}/api/categories/items?categoryId=${widget.category.id}'),
        headers: {'token': ApiService.sessionToken ?? ''},
      );
      final data = jsonDecode(res.body);
      final raw = (data['items'] as List? ?? []).cast<Map<String, dynamic>>();

      _items = raw.map((item) {
        final cv = item['criteriaValues'];
        final Map<String, String> values = {};
        if (cv is Map) {
          cv.forEach((k, v) {
            if (k != null && v != null) values[k.toString()] = v.toString();
          });
        }
        final rawItem = Map<String, dynamic>.from(item);
        rawItem['imageUrl'] ??= item['image_url'] ?? item['ImageUrl'] ?? item['image'];
        return ItemModel.fromJson(rawItem, values);
      }).toList();
    } catch (e) {
      print('collections _fetchItems ERROR: $e');
    }
  }

  Future<void> _addCollection(String name) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/collections'),
        headers: {
          'Content-Type': 'application/json',
          'token': ApiService.sessionToken ?? '',
        },
        body: jsonEncode(
            {'collectionName': name, 'categoryId': widget.category.id}),
      );
      final data = jsonDecode(res.body);
      setState(() {
        _collections
            .add(CollectionModel(id: data['id'], name: data['collectionName']));
      });
    } catch (_) {}
  }

  Future<void> _editCollection(String collectionId, String newName) async {
    try {
      await http.patch(
        Uri.parse('${ApiService.baseUrl}/api/collections'),
        headers: {
          'Content-Type': 'application/json',
          'token': ApiService.sessionToken ?? '',
        },
        body: jsonEncode(
            {'collectionId': collectionId, 'collectionName': newName}),
      );
      setState(() {
        _collections = _collections
            .map((c) => c.id == collectionId
                ? CollectionModel(id: collectionId, name: newName)
                : c)
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _deleteCollection(String collectionId) async {
    try {
      await http.delete(
        Uri.parse('${ApiService.baseUrl}/api/collections'),
        headers: {
          'Content-Type': 'application/json',
          'token': ApiService.sessionToken ?? '',
        },
        body: jsonEncode({'collectionId': collectionId}),
      );
      setState(() =>
          _collections.removeWhere((c) => c.id == collectionId));
    } catch (_) {}
  }

  void _logout() {
    ApiService.sessionToken = null;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  List<ItemModel> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    final q = _searchQuery.toLowerCase();
    return _items.where((item) {
      if (_searchField == 'Item Name') {
        return item.name.toLowerCase().contains(q);
      }
      final val = item.criteriaValues[_searchField] ?? '';
      return val.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showAddCollectionDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Collection',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'SquadaOne',
                fontWeight: FontWeight.w900)),
        content: _dialogTextField(ctrl, 'Collection name'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style:
                    TextStyle(color: Colors.white70, fontFamily: 'SquadaOne')),
          ),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              _addCollection(name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007ACC),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: const Text('Create',
                style: TextStyle(
                    fontFamily: 'SquadaOne', fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showCollectionOptions(CollectionModel col) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(col.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'SquadaOne',
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF007ACC)),
              title: const Text('Edit',
                  style:
                      TextStyle(color: Colors.white, fontFamily: 'SquadaOne')),
              onTap: () {
                Navigator.pop(context);
                _showEditCollectionDialog(col);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('Delete',
                  style:
                      TextStyle(color: Colors.white, fontFamily: 'SquadaOne')),
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
        backgroundColor: const Color(0xFF2A2A2A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Collection',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'SquadaOne',
                fontWeight: FontWeight.w900)),
        content: _dialogTextField(ctrl, 'Collection name'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style:
                    TextStyle(color: Colors.white70, fontFamily: 'SquadaOne')),
          ),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              _editCollection(col.id, name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007ACC),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: const Text('Save',
                style: TextStyle(
                    fontFamily: 'SquadaOne', fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showDeleteCollectionDialog(CollectionModel col) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Collection',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'SquadaOne',
                fontWeight: FontWeight.w900)),
        content: Text(
          'Are you sure you want to delete "${col.name}"? This cannot be undone.',
          style:
              const TextStyle(color: Colors.white70, fontFamily: 'SquadaOne'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style:
                    TextStyle(color: Colors.white70, fontFamily: 'SquadaOne')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteCollection(col.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: const Text('Delete',
                style: TextStyle(
                    fontFamily: 'SquadaOne', fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _dialogTextField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.black, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF0A5FAA), width: 2),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF252526),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/CPAD_Logo.png',
                    height: 96,
                    fit: BoxFit.contain,
                  ),
                  ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007ACC),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text('Log Out',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'SquadaOne')),
                  ),
                ],
              ),
            ),

            // Blue divider
            Container(height: 4, color: const Color(0xFF007ACC)),

            const SizedBox(height: 12),

            // Breadcrumb
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CategoriesPage()),
                        (_) => false,
                      ),
                      child: const Text('Home',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'SquadaOne',
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white)),
                    ),
                    const Text(' > ',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'SquadaOne')),
                    Text(widget.category.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'SquadaOne')),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Collections horizontal scroll row
            if (!_loading)
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Add collection button
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: OutlinedButton(
                        onPressed: _showAddCollectionDialog,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFF252526),
                          side: const BorderSide(
                              color: Color(0xFF007ACC), width: 2),
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 48),
                        ),
                        child: const Text('+',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF007ACC))),
                      ),
                    ),
                    // Collection chips
                    ..._collections.map((col) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onLongPress: () => _showCollectionOptions(col),
                            child: ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ItemsPage(
                                    category: widget.category,
                                    collection: col,
                                    allCollections: _collections,
                                    criteria: _criteria,
                                  ),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007ACC),
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                elevation: 0,
                              ),
                              child: Text(col.name,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'SquadaOne')),
                            ),
                          ),
                        )),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Search bar with dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Dropdown
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A3A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF007ACC), width: 1.5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _searchField,
                        dropdownColor: const Color(0xFF3A3A3A),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'SquadaOne',
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                        iconEnabledColor: const Color(0xFF007ACC),
                        items: [
                          'Item Name',
                          ..._criteria.map((c) => c.name),
                        ].map((field) => DropdownMenuItem(
                              value: field,
                              child: Text(field),
                            )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _searchField = val;
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Text field
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'SquadaOne',
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search by $_searchField…',
                          hintStyle: const TextStyle(
                            color: Colors.white38,
                            fontFamily: 'SquadaOne',
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF3A3A3A),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFF007ACC), width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFF007ACC), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFF007ACC), width: 2),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: Colors.white54, size: 18),
                                  onPressed: () => setState(() {
                                    _searchQuery = '';
                                    _searchController.clear();
                                  }),
                                )
                              : const Icon(Icons.search,
                                  color: Colors.white38, size: 18),
                        ),
                        onChanged: (val) =>
                            setState(() => _searchQuery = val.trim()),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Items grid (all items in this category)
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF007ACC)))
                  : _filteredItems.isEmpty
                      ? Center(
                          child: Text(
                              _items.isEmpty
                                  ? 'No items yet.'
                                  : 'No items match your search.',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontFamily: 'SquadaOne',
                                  fontSize: 16)))
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: _filteredItems.length,
                          itemBuilder: (_, i) {
                            final item = _filteredItems[i];
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
                                  MaterialPageRoute(
                                    builder: (_) => ItemEditPage(
                                      item: item,
                                      criteria: _criteria,
                                      category: widget.category,
                                      collection: col,
                                    ),
                                  ),
                                );
                                // Refresh after editing
                                setState(() => _loading = true);
                                await _fetchItems();
                                setState(() => _loading = false);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF007ACC),
                                      width: 2),
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: item.imageUrl != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                      top: Radius.circular(6)),
                                              child: Image.network(
                                                item.imageUrl!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(Icons.image,
                                                        color: Color(0xFF007ACC),
                                                        size: 48),
                                              ),
                                            )
                                          : const Center(
                                              child: Icon(Icons.image,
                                                  color: Color(0xFF007ACC),
                                                  size: 48)),
                                    ),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(6),
                                      child: Text(
                                        item.name,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'SquadaOne',
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}