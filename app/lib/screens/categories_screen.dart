import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/repo.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

const List<int> kPalette = [
  0xFFF4A261, 0xFF7BC67E, 0xFF8E8BEA, 0xFF5DADE2, 0xFFE76F51, 0xFFF6C85F, 0xFF9B7EDE,
  0xFFEF7C8E, 0xFFEBB9D6, 0xFF4FB3A9, 0xFF6C8EF5, 0xFFD78FD3, 0xFF34B892, 0xFF9AA0B4,
];

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txns = context.watch<TxnState>();
    final fin = context.fin;

    Widget section(String title, List<Category> cats) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
            child: Text(title.toUpperCase(),
                style: TextStyle(
                    color: fin.subtext,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
          ),
          Material(
            color: fin.card,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (final c in cats)
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c.colorValue.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(c.icon, color: c.colorValue, size: 20),
                  ),
                  title: Text(c.name),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context)
                      .push(fadeRoute(CategoryEditor(category: c))),
                ),
            ]),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.of(context).push(fadeRoute(const CategoryEditor())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New category'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        children: [
          section('Expense', txns.byKind('expense')),
          section('Income', txns.byKind('income')),
        ],
      ),
    );
  }
}

class CategoryEditor extends StatefulWidget {
  final Category? category;

  const CategoryEditor({super.key, this.category});

  @override
  State<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<CategoryEditor> {
  late final TextEditingController _name;
  late String _icon;
  late int _color;
  late String _kind;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _name = TextEditingController(text: c?.name ?? '');
    _icon = c?.iconKey ?? 'other';
    _color = c?.color ?? kPalette.first;
    _kind = c?.kind ?? 'expense';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final txns = context.read<TxnState>();
    final nav = Navigator.of(context);
    final db = AppDatabase.instance;
    final c = widget.category;
    final name = _name.text.trim();
    if (c == null) {
      await db.insertCategory(name, _icon, _color, _kind);
    } else {
      await db.updateCategory(Category(
          id: c.id,
          name: name,
          iconKey: _icon,
          color: _color,
          kind: c.kind,
          sort: c.sort));
    }
    await txns.load();
    nav.pop();
  }

  Future<void> _delete() async {
    final txns = context.read<TxnState>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete category?'),
        content: const Text(
            'Transactions in this category will move to Needs review.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.expense))),
        ],
      ),
    );
    if (ok == true) {
      await AppDatabase.instance.deleteCategory(widget.category!.id!);
      await txns.load();
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final color = Color(_color);
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? 'New category' : 'Edit category'),
        actions: [
          if (widget.category != null)
            IconButton(
                onPressed: _delete, icon: const Icon(Icons.delete_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(kCategoryIcons[_icon] ?? Icons.category_rounded,
                  color: color, size: 40),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Category name'),
            onChanged: (_) => setState(() {}),
          ),
          if (widget.category == null) ...[
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
          ],
          const SizedBox(height: 20),
          Text('Icon',
              style: TextStyle(color: fin.subtext, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final e in kCategoryIcons.entries)
                GestureDetector(
                  onTap: () => setState(() => _icon = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: fin.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _icon == e.key ? primary : fin.divider,
                          width: _icon == e.key ? 2.5 : 1),
                    ),
                    child: Icon(e.value, color: color),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Colour',
              style: TextStyle(color: fin.subtext, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in kPalette)
                GestureDetector(
                  onTap: () => setState(() => _color = p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(p),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _color == p ? primary : Colors.transparent,
                          width: 3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Save category',
            icon: Icons.check_rounded,
            onPressed: _name.text.trim().isEmpty ? null : _save,
          ),
        ],
      ),
    );
  }
}
