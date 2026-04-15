import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'login.dart' show AppBackground, AppColors, webCard, LoginPage;
import 'dialog_helpers.dart';
import 'collections.dart';
import 'services/api_service.dart';

// ─── Model ────────────────────────────────────────────────────────────────
class Category {
  final String id;
  final String name;
  Category({required this.id, required this.name});
  factory Category.fromJson(Map<String, dynamic> j) =>
      Category(id: j['_id'], name: j['categoryName']);
}

// ─── Page ─────────────────────────────────────────────────────────────────
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

  // ── API ──────────────────────────────────────────────────────────────
  Future<void> _fetchCategories() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/categories'),
        headers: {'token': ApiService.sessionToken ?? ''},
      );
      if (res.statusCode == 401 || res.statusCode == 403) { _logout(); return; }
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
        headers: {'Content-Type': 'application/json', 'token': ApiService.sessionToken ?? ''},
        body: jsonEncode({'categoryName': name}),
      );
      if (!catRes.statusCode.toString().startsWith('2')) return;
      final catData = jsonDecode(catRes.body);
      final newId = catData['_id'];

      for (final c in criteria) {
        await http.post(
          Uri.parse('${ApiService.baseUrl}/api/categories/criteria'),
          headers: {'Content-Type': 'application/json', 'token': ApiService.sessionToken ?? ''},
          body: jsonEncode({'criteriaName': c, 'categoryId': newId}),
        );
      }
      setState(() => _categories.add(Category(id: newId, name: catData['categoryName'])));
    } catch (_) {}
  }

  Future<void> _editCategory(String id, String name, List<String> newCriteria) async {
    try {
      await http.patch(
        Uri.parse('${ApiService.baseUrl}/api/categories'),
        headers: {'Content-Type': 'application/json', 'token': ApiService.sessionToken ?? ''},
        body: jsonEncode({'categoryId': id, 'categoryName': name}),
      );
      final existRes = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/categories/criteria?categoryId=$id'),
        headers: {'token': ApiService.sessionToken ?? ''},
      );
      final existing = (jsonDecode(existRes.body)['criteria'] as List)
          .cast<Map<String, dynamic>>();
      for (final ec in existing) {
        if (!newCriteria.contains(ec['criteriaName'])) {
          await http.delete(
            Uri.parse('${ApiService.baseUrl}/api/categories/criteria'),
            headers: {'Content-Type': 'application/json', 'token': ApiService.sessionToken ?? ''},
            body: jsonEncode({'criteriaId': ec['_id']}),
          );
        }
      }
      for (final c in newCriteria) {
        if (!existing.any((ec) => ec['criteriaName'] == c)) {
          await http.post(
            Uri.parse('${ApiService.baseUrl}/api/categories/criteria'),
            headers: {'Content-Type': 'application/json', 'token': ApiService.sessionToken ?? ''},
            body: jsonEncode({'criteriaName': c, 'categoryId': id}),
          );
        }
      }
      setState(() {
        _categories = _categories
            .map((cat) => cat.id == id ? Category(id: id, name: name) : cat)
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _deleteCategory(String id) async {
    try {
      await http.delete(
        Uri.parse('${ApiService.baseUrl}/api/categories'),
        headers: {'Content-Type': 'application/json', 'token': ApiService.sessionToken ?? ''},
        body: jsonEncode({'categoryId': id}),
      );
      setState(() => _categories.removeWhere((c) => c.id == id));
    } catch (_) {}
  }

  Future<List<String>> _getCriteria(String categoryId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/categories/criteria?categoryId=$categoryId'),
        headers: {'token': ApiService.sessionToken ?? ''},
      );
      return (jsonDecode(res.body)['criteria'] as List)
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

  // ── Dialogs ──────────────────────────────────────────────────────────
  void _showAddDialog() {
    final nameCtrl      = TextEditingController();
    final criteriaCtrl  = TextEditingController();
    final criteria      = <String>[];

    _showCategoryDialog(
      title: 'New Category',
      confirmLabel: 'Create',
      nameCtrl: nameCtrl,
      criteriaCtrl: criteriaCtrl,
      criteriaList: criteria,
      onConfirm: () {
        final name = nameCtrl.text.trim();
        if (name.isEmpty) return;
        Navigator.pop(context);
        _addCategory(name, criteria);
      },
    );
  }

  void _showEditDialog(Category cat) async {
    final existingCriteria = await _getCriteria(cat.id);
    final nameCtrl     = TextEditingController(text: cat.name);
    final criteriaCtrl = TextEditingController();
    final criteria     = List<String>.from(existingCriteria);

    if (!mounted) return;
    _showCategoryDialog(
      title: 'Edit Category',
      confirmLabel: 'Save',
      nameCtrl: nameCtrl,
      criteriaCtrl: criteriaCtrl,
      criteriaList: criteria,
      onConfirm: () {
        final name = nameCtrl.text.trim();
        if (name.isEmpty) return;
        Navigator.pop(context);
        _editCategory(cat.id, name, criteria);
      },
    );
  }

  void _showCategoryDialog({
    required String title,
    required String confirmLabel,
    required TextEditingController nameCtrl,
    required TextEditingController criteriaCtrl,
    required List<String> criteriaList,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppColors.bgRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.accentBorder, width: 1),
          ),
          title: Text(title,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'SquadaOne',
                  fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dlgLabel('Category Name'),
                dlgTextField(nameCtrl, 'e.g. Trading Cards'),
                const SizedBox(height: 16),
                dlgLabel('Criteria'),
                Row(children: [
                  Expanded(child: dlgTextField(criteriaCtrl, 'e.g. Condition')),
                  const SizedBox(width: 8),
                  accentIconButton(Icons.add, () {
                    final v = criteriaCtrl.text.trim();
                    if (v.isNotEmpty) {
                      setDlg(() { criteriaList.add(v); criteriaCtrl.clear(); });
                    }
                  }),
                ]),
                if (criteriaList.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: criteriaList
                        .map((c) => criteriaChip(c, () => setDlg(() => criteriaList.remove(c))))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            dlgCancelBtn(ctx),
            dlgConfirmBtn(confirmLabel, onConfirm),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Category cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.accentBorder, width: 1),
        ),
        title: const Text('Delete Category',
            style: TextStyle(color: AppColors.textPrimary, fontFamily: 'SquadaOne', fontSize: 18)),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: AppColors.textMuted, fontFamily: 'SquadaOne', fontSize: 14),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                  text: '"${cat.name}"',
                  style: const TextStyle(color: AppColors.textPrimary)),
              const TextSpan(text: '? This cannot be undone.'),
            ],
          ),
        ),
        actions: [
          dlgCancelBtn(ctx),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _deleteCategory(cat.id); },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.red, fontFamily: 'SquadaOne', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showOptionsSheet(Category cat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.accentBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Text(cat.name,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'SquadaOne',
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Divider(color: AppColors.borderSubtle),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.accent),
              title: const Text('Edit',
                  style: TextStyle(color: AppColors.textPrimary, fontFamily: 'SquadaOne')),
              onTap: () { Navigator.pop(context); _showEditDialog(cat); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.red),
              title: const Text('Delete',
                  style: TextStyle(color: AppColors.red, fontFamily: 'SquadaOne')),
              onTap: () { Navigator.pop(context); _showDeleteDialog(cat); },
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
              // Thin accent divider — matches website's border-bottom on header
              Container(height: 1, color: AppColors.accentBorder),

              // Breadcrumb
              buildBreadcrumb([
                BreadcrumbItem(label: 'Home'),
              ]),

              // Add button — full-width outlined, matching website's + button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: OutlinedButton(
                  onPressed: _showAddDialog,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: const BorderSide(color: AppColors.accentBorder, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: AppColors.accentDim,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: AppColors.accent, size: 20),
                      SizedBox(width: 6),
                      Text('Add Category',
                          style: TextStyle(
                              color: AppColors.accent,
                              fontFamily: 'SquadaOne',
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),

              // Category list
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                    : _categories.isEmpty
                        ? const Center(
                            child: Text('No categories yet.',
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontFamily: 'SquadaOne',
                                    fontSize: 15)))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: _categories.length,
                            itemBuilder: (_, i) => _buildCategoryRow(_categories[i]),
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
      color: Colors.transparent,
      child: Row(
        children: [
          Image.asset('assets/CPAD_Logo.png', height: 44, fit: BoxFit.contain),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Collector's Pair-A-Dice",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w400,
                fontFamily: 'SquadaOne',
                letterSpacing: 0.6,
              ),
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

  Widget _buildCategoryRow(Category cat) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onLongPress: () => _showOptionsSheet(cat),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.accentBorder, width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(cat.name,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'SquadaOne',
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CollectionsPage(category: cat)),
            ),
          ),
        ),
      ),
    );
  }
}
