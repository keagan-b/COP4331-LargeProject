import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
      // Fetch criteria fresh so IDs are guaranteed to match
      List<CriterionModel> freshCriteria = widget.criteria;
      try {
        final crRes = await http.get(
          Uri.parse(
              '${ApiService.baseUrl}/api/categories/criteria?categoryId=${widget.category.id}'),
          headers: {'token': ApiService.sessionToken ?? ''},
        );
        final crData = jsonDecode(crRes.body);
        freshCriteria = (crData['criteria'] as List)
            .map((e) => CriterionModel.fromJson(e))
            .toList();
      } catch (_) {}

      final res = await http.get(
        Uri.parse(
            '${ApiService.baseUrl}/api/categories/items?categoryId=${widget.category.id}'),
        headers: {'token': ApiService.sessionToken ?? ''},
      );
      final data = jsonDecode(res.body);
      final raw = (data['items'] as List)
          .cast<Map<String, dynamic>>()
          .where((item) =>
              item['collectionId']?.toString() == widget.collection.id)
          .toList();

      final hydrated = await Future.wait(raw.map((item) async {
        final Map<String, String> values = {};
        try {
          final cvRes = await http.get(
            Uri.parse(
                '${ApiService.baseUrl}/api/items/criteria/all?itemId=${item['_id']}'),
            headers: {'token': ApiService.sessionToken ?? ''},
          );
          final cvData = jsonDecode(cvRes.body);
          print('=== CRITERIA RESPONSE for item ${item['_id']} ===');
          print('Raw body: ${cvRes.body}');
          print('Parsed: $cvData');
          print('freshCriteria IDs: ${freshCriteria.map((c) => '${c.id}=${c.name}').toList()}');
          for (final cv in (cvData['itemCriteria'] ?? [])) {
            print('cv entry: $cv');
            print('categoryCriteriaId type: ${cv['categoryCriteriaId'].runtimeType}');
            print('categoryCriteriaId value: ${cv['categoryCriteriaId']}');
            // Try matching by ID first
            final rawId = cv['categoryCriteriaId'];
            final idStr = rawId is Map
                ? (rawId['\$oid'] ?? rawId['_id'] ?? rawId.toString())
                : rawId.toString();

            CriterionModel match = freshCriteria.firstWhere(
              (c) => c.id == idStr,
              orElse: () => CriterionModel(id: '', name: ''),
            );

            // Fallback: match by criteriaName field if present in response
            if (match.name.isEmpty && cv['criteriaName'] != null) {
              match = freshCriteria.firstWhere(
                (c) => c.name == cv['criteriaName'].toString(),
                orElse: () => CriterionModel(id: '', name: ''),
              );
            }

            if (match.name.isNotEmpty && cv['criteriaValue'] != null) {
              values[match.name] = cv['criteriaValue'].toString();
            }
          }
        } catch (_) {}
        return ItemModel.fromJson(item, values);
      }));

      if (mounted) {
        setState(() {
          _items = hydrated;
          _loading = false;
        });
      }
    } catch (_) {
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
                fontFamily: 'Impact',
                fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Item Name',
                  style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Impact',
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
                                  fontFamily: 'Impact',
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
                    TextStyle(color: Colors.white70, fontFamily: 'Impact')),
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
                    fontFamily: 'Impact', fontWeight: FontWeight.w900)),
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
                            fontFamily: 'Impact')),
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
                              fontFamily: 'Impact',
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white)),
                    ),
                    const Text(' > ',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Impact')),
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
                              fontFamily: 'Impact',
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white)),
                    ),
                    const Text(' > ',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Impact')),
                    Text(widget.collection.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Impact')),
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
                                  fontFamily: 'Impact',
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
                                    fontFamily: 'Impact',
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
                          fontFamily: 'Impact',
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
                          fontFamily: 'Impact',
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search by $_searchField…',
                          hintStyle: const TextStyle(
                            color: Colors.white38,
                            fontFamily: 'Impact',
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
                                        fontFamily: 'Impact',
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
                                      fontFamily: 'Impact',
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

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
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
                            fontFamily: 'Impact')),
                  ),
                ],
              ),
            ),

            // Blue divider
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
                            fontFamily: 'Impact',
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
                                fontFamily: 'Impact',
                                fontWeight: FontWeight.w900,
                                fontSize: 16)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image placeholder
                    GestureDetector(
                      onTap: () {
                        // Future: hook up camera/gallery
                      },
                      child: Container(
                        width: double.infinity,
                        height: 280,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF007ACC), width: 2),
                        ),
                        child: widget.item.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  widget.item.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.add,
                                        color: Color(0xFF007ACC), size: 64),
                                  ),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.add,
                                    color: Color(0xFF007ACC), size: 64)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Item name field
                    TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontFamily: 'Impact',
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
                                          color: Colors.white,
                                          fontFamily: 'Impact',
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

                    // Delete section
                    if (!_showDeleteConfirm)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showDeleteConfirm = true),
                        child: const Text('Delete Item',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontFamily: 'Impact',
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
                                fontFamily: 'Impact',
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
                                        fontFamily: 'Impact',
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
                                        fontFamily: 'Impact',
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