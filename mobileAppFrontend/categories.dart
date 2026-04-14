import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'login.dart';
import 'collections.dart';
import 'services/api_service.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class Category {
  final String id;
  final String name;
  Category({required this.id, required this.name});
  factory Category.fromJson(Map<String, dynamic> j) =>
      Category(id: j['_id'], name: j['categoryName']);
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  // ── API calls ──────────────────────────────────────────────────────────────

  Future<void> _fetchCategories() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/categories'),
        headers: {'token': ApiService.sessionToken ?? ''},
      );
      if (res.statusCode == 401 || res.statusCode == 403) {
        _logout();
        return;
      }
      final data = jsonDecode(res.body);
      setState(() {
        _categories = (data['userCategories'] as List)
            .map((e) => Category.fromJson(e))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addCategory(String name, List<String> criteria) async {
    try {
      final catRes = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/categories'),
        headers: {
          'Content-Type': 'application/json',
          'token': ApiService.sessionToken ?? '',
        },
        body: jsonEncode({'categoryName': name}),
      );
      if (!catRes.statusCode.toString().startsWith('2')) return;
      final catData = jsonDecode(catRes.body);
      final newId = catData['_id'];

      for (final c in criteria) {
        await http.post(
          Uri.parse('${ApiService.baseUrl}/api/categories/criteria'),
          headers: {
            'Content-Type': 'application/json',
            'token': ApiService.sessionToken ?? '',
          },
          body: jsonEncode({'criteriaName': c, 'categoryId': newId}),
        );
      }

      setState(() {
        _categories.add(Category(id: newId, name: catData['categoryName']));
      });
    } catch (_) {}
  }

  Future<void> _editCategory(
      String categoryId, String name, List<String> newCriteria) async {
    try {
      await http.patch(
        Uri.parse('${ApiService.baseUrl}/api/categories'),
        headers: {
          'Content-Type': 'application/json',
          'token': ApiService.sessionToken ?? '',
        },
        body: jsonEncode({'categoryId': categoryId, 'categoryName': name}),
      );

      // Sync criteria
      final existRes = await http.get(
        Uri.parse(
            '${ApiService.baseUrl}/api/categories/criteria?categoryId=$categoryId'),
        headers: {'token': ApiService.sessionToken ?? ''},
      );
      final existData = jsonDecode(existRes.body);
      final existing =
          (existData['criteria'] as List).cast<Map<String, dynamic>>();

      // Delete removed
      for (final ec in existing) {
        if (!newCriteria.contains(ec['criteriaName'])) {
          await http.delete(
            Uri.parse('${ApiService.baseUrl}/api/categories/criteria'),
            headers: {
              'Content-Type': 'application/json',
              'token': ApiService.sessionToken ?? '',
            },
            body: jsonEncode({'criteriaId': ec['_id']}),
          );
        }
      }
      // Add new
      for (final c in newCriteria) {
        if (!existing.any((ec) => ec['criteriaName'] == c)) {
          await http.post(
            Uri.parse('${ApiService.baseUrl}/api/categories/criteria'),
            headers: {
              'Content-Type': 'application/json',
              'token': ApiService.sessionToken ?? '',
            },
            body: jsonEncode({'criteriaName': c, 'categoryId': categoryId}),
          );
        }
      }

      setState(() {
        _categories = _categories
            .map((cat) =>
                cat.id == categoryId ? Category(id: categoryId, name: name) : cat)
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _deleteCategory(String categoryId) async {
    try {
      await http.delete(
        Uri.parse('${ApiService.baseUrl}/api/categories'),
        headers: {
          'Content-Type': 'application/json',
          'token': ApiService.sessionToken ?? '',
        },
        body: jsonEncode({'categoryId': categoryId}),
      );
      setState(() =>
          _categories.removeWhere((cat) => cat.id == categoryId));
    } catch (_) {}
  }

  Future<List<String>> _getCriteria(String categoryId) async {
    try {
      final res = await http.get(
        Uri.parse(
            '${ApiService.baseUrl}/api/categories/criteria?categoryId=$categoryId'),
        headers: {'token': ApiService.sessionToken ?? ''},
      );
      final data = jsonDecode(res.body);
      return (data['criteria'] as List)
          .map((c) => c['criteriaName'] as String)
          .toList();
    } catch (_) {
      return [];
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

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    final criteriaCtrl = TextEditingController();
    final criteria = <String>[];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('New Category',
              style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Impact',
                  fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name field
                const Text('Name',
                    style: TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Impact',
                        fontSize: 13)),
                const SizedBox(height: 6),
                _dialogTextField(nameCtrl, 'Category name'),
                const SizedBox(height: 16),
                // Criteria field
                const Text('Criteria',
                    style: TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Impact',
                        fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _dialogTextField(criteriaCtrl, 'e.g. Author')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final v = criteriaCtrl.text.trim();
                        if (v.isNotEmpty) {
                          setDlg(() {
                            criteria.add(v);
                            criteriaCtrl.clear();
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007ACC),
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      child: const Text('Add',
                          style: TextStyle(
                              fontFamily: 'Impact',
                              fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                if (criteria.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...criteria.map((c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            const Icon(Icons.label_outline,
                                color: Color(0xFF007ACC), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(c,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Impact',
                                      fontSize: 14)),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  setDlg(() => criteria.remove(c)),
                              child: const Icon(Icons.close,
                                  color: Colors.redAccent, size: 18),
                            ),
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
                  style: TextStyle(
                      color: Colors.white70, fontFamily: 'Impact')),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                _addCategory(name, criteria);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007ACC),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: const Text('Create',
                  style: TextStyle(
                      fontFamily: 'Impact', fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(Category cat) async {
    final existingCriteria = await _getCriteria(cat.id);
    final nameCtrl = TextEditingController(text: cat.name);
    final criteriaCtrl = TextEditingController();
    final criteria = List<String>.from(existingCriteria);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Category',
              style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Impact',
                  fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Name',
                    style: TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Impact',
                        fontSize: 13)),
                const SizedBox(height: 6),
                _dialogTextField(nameCtrl, 'Category name'),
                const SizedBox(height: 16),
                const Text('Criteria',
                    style: TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Impact',
                        fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _dialogTextField(criteriaCtrl, 'e.g. Author')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final v = criteriaCtrl.text.trim();
                        if (v.isNotEmpty) {
                          setDlg(() {
                            criteria.add(v);
                            criteriaCtrl.clear();
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007ACC),
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      child: const Text('Add',
                          style: TextStyle(
                              fontFamily: 'Impact',
                              fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                if (criteria.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...criteria.map((c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            const Icon(Icons.label_outline,
                                color: Color(0xFF007ACC), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(c,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Impact',
                                      fontSize: 14)),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  setDlg(() => criteria.remove(c)),
                              child: const Icon(Icons.close,
                                  color: Colors.redAccent, size: 18),
                            ),
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
                  style: TextStyle(
                      color: Colors.white70, fontFamily: 'Impact')),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                _editCategory(cat.id, name, criteria);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007ACC),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: const Text('Save',
                  style: TextStyle(
                      fontFamily: 'Impact', fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteCategoryDialog(Category cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Category',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Impact',
                fontWeight: FontWeight.w900)),
        content: Text(
          'Are you sure you want to delete "${cat.name}"? This cannot be undone.',
          style: const TextStyle(color: Colors.white70, fontFamily: 'Impact'),
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
              Navigator.pop(ctx);
              _deleteCategory(cat.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: const Text('Delete',
                style: TextStyle(
                    fontFamily: 'Impact', fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

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
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide:
              const BorderSide(color: Color(0xFF0A5FAA), width: 2),
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
                child: const Text(
                  'Home',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Impact',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Add button
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                height: 64,
                child: OutlinedButton(
                  onPressed: _showAddCategoryDialog,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF252526),
                    side: const BorderSide(
                        color: Color(0xFF007ACC), width: 3),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('+',
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF007ACC))),
                ),
              ),
            ),

            // Category list
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF007ACC)))
                  : _categories.isEmpty
                      ? const Center(
                          child: Text('No categories yet.',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontFamily: 'Impact',
                                  fontSize: 16)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          itemCount: _categories.length,
                          itemBuilder: (_, i) {
                            final cat = _categories[i];
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              child: GestureDetector(
                                onLongPress: () =>
                                    _showCategoryOptions(cat),
                                child: ElevatedButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CollectionsPage(
                                        category: cat,
                                      ),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF007ACC),
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 18),
                                    elevation: 0,
                                    minimumSize:
                                        const Size(double.infinity, 56),
                                  ),
                                  child: Text(cat.name,
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'Impact')),
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

  void _showCategoryOptions(Category cat) {
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
            Text(cat.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Impact',
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            ListTile(
              leading:
                  const Icon(Icons.edit, color: Color(0xFF007ACC)),
              title: const Text('Edit',
                  style: TextStyle(
                      color: Colors.white, fontFamily: 'Impact')),
              onTap: () {
                Navigator.pop(context);
                _showEditCategoryDialog(cat);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('Delete',
                  style: TextStyle(
                      color: Colors.white, fontFamily: 'Impact')),
              onTap: () {
                Navigator.pop(context);
                _showDeleteCategoryDialog(cat);
              },
            ),
          ],
        ),
      ),
    );
  }
}