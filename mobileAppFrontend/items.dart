import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'login.dart';
import 'categories.dart';
import 'collections.dart';
import 'services/api_service.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

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

  factory ItemModel.fromJson(
      Map<String, dynamic> j, Map<String, String> values) {
    return ItemModel(
      id: j['_id'],
      name: j['itemName'],
      categoryId: j['categoryId'] ?? '',
      collectionId: j['collectionId']?.toString(),
      imageUrl: j['imageUrl'],
      criteriaValues: values,
    );
  }

  ItemModel copyWith({
    String? name,
    Map<String, String>? criteriaValues,
    String? imageUrl,
  }) {
    return ItemModel(
      id: id,
      name: name ?? this.name,
      categoryId: categoryId,
      collectionId: collectionId,
      imageUrl: imageUrl ?? this.imageUrl,
      criteriaValues: criteriaValues ?? this.criteriaValues,
    );
  }
}

// ─── Items Page ───────────────────────────────────────────────────────────────

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

  // Sorting — '__name__' is the sentinel for item name sort
  late String _sortCriteria;
  bool _sortAsc = true;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _searchField = 'Item Name';

  @override
  void initState() {
    super.initState();
    _sortCriteria = '__name__';
    _fetchItems();
  }

  // ── API ────────────────────────────────────────────────────────────────────

  Future<void> _fetchItems() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse(
            '${ApiService.baseUrl}/api/categories/items?categoryId=${widget.category.id}'),
        headers: {'token': ApiService.sessionToken ?? ''},
      );
      final data = jsonDecode(res.body);
      final raw = (data['items'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .where((item) =>
              item['collectionId']?.toString() == widget.collection.id)
          .toList();

      final items = raw.map((item) {
        // criteriaValues comes back as a map keyed by name — use it directly
        final cv = item['criteriaValues'];
        final Map<String, String> values = {};
        if (cv is Map) {
          cv.forEach((k, v) {
            if (k != null && v != null) {
              values[k.toString()] = v.toString();
            }
          });
        }

        // Resolve imageUrl — handle alternate key names
        final rawItem = Map<String, dynamic>.from(item);
        rawItem['imageUrl'] ??= item['image_url'] ?? item['ImageUrl'] ?? item['image'];

        return ItemModel.fromJson(rawItem, values);
      }).toList();

      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e, stack) {
      print('_fetchItems ERROR: $e');
      print(stack);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addItem(
      String name, Map<String, String> criteriaValues) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/items'),
        headers: {
          'Content-Type': 'application/json',
          'token': ApiService.sessionToken ?? '',
        },
        body: jsonEncode({
          'itemName': name,
          'categoryId': widget.category.id,
          'collectionId': widget.collection.id,
          'criteriaValues': criteriaValues,
        }),
      );
      final data = jsonDecode(res.body);
      setState(() {
        _items.add(ItemModel(
          id: data['_id'],
          name: data['itemName'],
          categoryId: widget.category.id,
          collectionId: widget.collection.id,
          criteriaValues: criteriaValues,
        ));
      });
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
    final base = _sortedItems;
    if (_searchQuery.isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base.where((item) {
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

  // ── Sort ───────────────────────────────────────────────────────────────────

  List<ItemModel> get _sortedItems {
    final list = List<ItemModel>.from(_items);
    if (_sortCriteria == '__name__') {
      list.sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      list.sort((a, b) {
        final aVal = (a.criteriaValues[_sortCriteria] ?? '').toLowerCase();
        final bVal = (b.criteriaValues[_sortCriteria] ?? '').toLowerCase();
        return aVal.compareTo(bVal);
      });
    }
    if (!_sortAsc) return list.reversed.toList();
    return list;
  }

  void _onCriteriaTap(String criteriaName) {
    setState(() {
      if (_sortCriteria == criteriaName) {
        _sortAsc = !_sortAsc;
      } else {
        _sortCriteria = criteriaName;
        _sortAsc = true;
      }
    });
  }

  // ── Add Item Dialog ────────────────────────────────────────────────────────

  void _showAddItemDialog() {
    final nameCtrl = TextEditingController();
    final criteriaCtrl = <String, TextEditingController>{
      for (final c in widget.criteria) c.name: TextEditingController()
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Item',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'SquadaOne',
                fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Item Name',
                  style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'SquadaOne',
                      fontSize: 13)),
              const SizedBox(height: 6),
              _dialogTextField(nameCtrl, 'Name'),
              if (widget.criteria.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.white24),
                ...widget.criteria.map((c) => Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontFamily: 'SquadaOne',
                                  fontSize: 13)),
                          const SizedBox(height: 4),
                          _dialogTextField(criteriaCtrl[c.name]!, c.name),
                        ],
                      ),
                    )),
              ],
            ],
          ),
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
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final values = <String, String>{
                for (final c in widget.criteria)
                  c.name: criteriaCtrl[c.name]!.text.trim()
              };
              Navigator.pop(ctx);
              _addItem(name, values);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007ACC),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: const Text('Add Item',
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
                child: Wrap(
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
                    GestureDetector(
                      onTap: () => Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CollectionsPage(
                                  category: widget.category,
                                )),
                        (_) => false,
                      ),
                      child: Text(widget.category.name,
                          style: const TextStyle(
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
                    Text(widget.collection.name,
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

            // Sort buttons row
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Name sort button (always first)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ElevatedButton(
                      onPressed: () => _onCriteriaTap('__name__'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _sortCriteria == '__name__'
                            ? const Color(0xFF007ACC)
                            : const Color(0xFF3A3A3A),
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Name',
                              style: TextStyle(
                                  fontFamily: 'SquadaOne',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14)),
                          if (_sortCriteria == '__name__') ...[
                            const SizedBox(width: 4),
                            Icon(
                              _sortAsc
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 14,
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                  // Criteria sort buttons
                  ...widget.criteria.map((c) {
                    final isActive = _sortCriteria == c.name;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ElevatedButton(
                        onPressed: () => _onCriteriaTap(c.name),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isActive
                              ? const Color(0xFF007ACC)
                              : const Color(0xFF3A3A3A),
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(c.name,
                                style: const TextStyle(
                                    fontFamily: 'SquadaOne',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14)),
                            if (isActive) ...[
                              const SizedBox(width: 4),
                              Icon(
                                _sortAsc
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                size: 14,
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 8),

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
                          ...widget.criteria.map((c) => c.name),
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

            const SizedBox(height: 8),

            // Items grid
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF007ACC)))
                  : _filteredItems.isEmpty && _searchQuery.isNotEmpty
                      ? Column(
                          children: [
                            // Still show add card at top
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: GestureDetector(
                                onTap: _showAddItemDialog,
                                child: Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A2A2A),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFF007ACC),
                                        width: 2),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.add,
                                        color: Color(0xFF007ACC), size: 48),
                                  ),
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Center(
                                child: Text('No items match your search.',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontFamily: 'SquadaOne',
                                        fontSize: 16)),
                              ),
                            ),
                          ],
                        )
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
                      itemCount: _filteredItems.length + 1, // +1 for add card
                      itemBuilder: (_, i) {
                        // First card = add button
                        if (i == 0) {
                          return GestureDetector(
                            onTap: _showAddItemDialog,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFF007ACC), width: 2),
                              ),
                              child: const Center(
                                child: Icon(Icons.add,
                                    color: Color(0xFF007ACC), size: 48),
                              ),
                            ),
                          );
                        }

                        final item = _filteredItems[i - 1];
                        return GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ItemEditPage(
                                  item: item,
                                  criteria: widget.criteria,
                                  category: widget.category,
                                  collection: widget.collection,
                                ),
                              ),
                            );
                            // Refresh after editing
                            await _fetchItems();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFF007ACC), width: 2),
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

// ─── Item Edit Page ───────────────────────────────────────────────────────────

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

  // Image state
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
        c.name: TextEditingController(
            text: widget.item.criteriaValues[c.name] ?? '')
    };
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final ctrl in _criteriaCtrl.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // ── Image picking ──────────────────────────────────────────────────────────

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Change Photo',
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'SquadaOne',
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF007ACC)),
                title: const Text('Choose from Photos',
                    style: TextStyle(color: Colors.white, fontFamily: 'SquadaOne')),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF007ACC)),
                title: const Text('Take a Photo',
                    style: TextStyle(color: Colors.white, fontFamily: 'SquadaOne')),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return;
      setState(() {
        _pickedImage = picked;
        _uploadingImage = true;
      });
      await _uploadPickedImage(picked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not access ${source == ImageSource.camera ? "camera" : "photos"}: $e'),
        backgroundColor: Colors.redAccent,
      ));
      setState(() => _uploadingImage = false);
    }
  }

  Future<void> _uploadPickedImage(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/api/upload-image'),
      )
        ..headers['token'] = ApiService.sessionToken ?? ''
        ..files.add(http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: file.name,
          contentType: http.MediaType.parse(mimeType),
        ));

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);

      if (!mounted) return;

      print('IMAGE UPLOAD STATUS: ${res.statusCode}');
      print('IMAGE UPLOAD BODY: ${res.body}');
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        // Try common response key names for the returned URL
        final newUrl = data['url'] as String?;
        print('IMAGE URL from response: $newUrl');
        setState(() {
          _currentImageUrl = newUrl;
          _pickedImage = null;
          _uploadingImage = false;
        });
      } else {
        setState(() => _uploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Image upload failed (${res.statusCode}): ${res.body}'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Upload error: $e'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  // ── Save / Delete ──────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final values = <String, String>{
        for (final c in widget.criteria)
          c.name: _criteriaCtrl[c.name]!.text.trim()
      };

      await http.patch(
        Uri.parse('${ApiService.baseUrl}/api/items'),
        headers: {
          'Content-Type': 'application/json',
          'token': ApiService.sessionToken ?? '',
        },
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
        headers: {
          'Content-Type': 'application/json',
          'token': ApiService.sessionToken ?? '',
        },
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
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  // ── Image widget ───────────────────────────────────────────────────────────

  Widget _buildImageSection() {
    Widget imageContent;

    if (_uploadingImage) {
      imageContent = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF007ACC)),
            SizedBox(height: 12),
            Text('Uploading…',
                style: TextStyle(
                    color: Colors.white54,
                    fontFamily: 'SquadaOne',
                    fontSize: 14)),
          ],
        ),
      );
    } else if (_pickedImage != null) {
      imageContent = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(_pickedImage!.path),
          fit: BoxFit.contain,
          width: double.infinity,
        ),
      );
    } else if (_currentImageUrl != null) {
      imageContent = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          _currentImageUrl!,
          fit: BoxFit.contain,
          width: double.infinity,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image, color: Color(0xFF007ACC), size: 64),
          ),
        ),
      );
    } else {
      imageContent = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              color: Color(0xFF007ACC), size: 64),
          SizedBox(height: 8),
          Text('Tap to add photo',
              style: TextStyle(
                  color: Colors.white38,
                  fontFamily: 'SquadaOne',
                  fontSize: 14)),
        ],
      );
    }

    return GestureDetector(
      onTap: _uploadingImage ? null : _showImageSourceSheet,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 200, maxHeight: 420),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF007ACC), width: 2),
        ),
        child: Stack(
          children: [
            SizedBox(width: double.infinity, child: imageContent),
            if (!_uploadingImage &&
                (_pickedImage != null || _currentImageUrl != null))
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF007ACC).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.edit, color: Colors.white, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

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

            Container(height: 4, color: const Color(0xFF007ACC)),

            const SizedBox(height: 12),

            // Back / Save row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007ACC),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text('Back',
                        style: TextStyle(
                            fontFamily: 'SquadaOne',
                            fontWeight: FontWeight.w900,
                            fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007ACC),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Save',
                            style: TextStyle(
                                fontFamily: 'SquadaOne',
                                fontWeight: FontWeight.w900,
                                fontSize: 16)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageSection(),

                    const SizedBox(height: 16),

                    TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontFamily: 'SquadaOne',
                          fontWeight: FontWeight.w900),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Item name',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                              color: Color(0xFF0A5FAA), width: 2),
                        ),
                      ),
                    ),

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
                                          color: Colors.white,
                                          fontFamily: 'SquadaOne',
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15)),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _criteriaCtrl[c.name],
                                    style: const TextStyle(
                                        color: Colors.black, fontSize: 14),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          borderSide: BorderSide.none),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          borderSide: BorderSide.none),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF0A5FAA),
                                            width: 2),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const Divider(color: Colors.white24),
                    ],

                    const SizedBox(height: 16),

                    if (!_showDeleteConfirm)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showDeleteConfirm = true),
                        child: const Text('Delete Item',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontFamily: 'SquadaOne',
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.redAccent)),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Are you sure you want to delete "${widget.item.name}"?',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontFamily: 'SquadaOne',
                                fontSize: 14),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () => setState(
                                    () => _showDeleteConfirm = false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3A3A3A),
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                  elevation: 0,
                                ),
                                child: const Text('Cancel',
                                    style: TextStyle(
                                        fontFamily: 'SquadaOne',
                                        fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _saving ? null : _delete,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                  elevation: 0,
                                ),
                                child: const Text('Confirm Delete',
                                    style: TextStyle(
                                        fontFamily: 'SquadaOne',
                                        fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                        ],
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}