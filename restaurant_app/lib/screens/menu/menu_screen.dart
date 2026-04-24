import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List<dynamic> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getCategories();
      if (res.data['success'] == true) {
        _categories = res.data['data'] ?? [];
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _addCategory() async {
    final nameC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
            controller: nameC,
            decoration: const InputDecoration(hintText: 'Category name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ApiService.addCategory({'name': nameC.text});
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669)),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _addItem(int categoryId) async {
    final nameC = TextEditingController();
    final priceC = TextEditingController();
    final descC = TextEditingController();
    bool isVeg = true;
    File? pickedImage;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Menu Item'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Image picker
              GestureDetector(
                onTap: () async {
                  final img = await ImagePicker()
                      .pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (img != null) setS(() => pickedImage = File(img.path));
                },
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: pickedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.file(pickedImage!, fit: BoxFit.cover))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 36, color: Colors.grey.shade400),
                            const SizedBox(height: 6),
                            Text('Tap to add photo',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 13)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: nameC,
                  decoration:
                      const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                  controller: priceC,
                  decoration:
                      const InputDecoration(labelText: 'Price (₹)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              TextField(
                  controller: descC,
                  decoration:
                      const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  maxLines: 2),
              const SizedBox(height: 6),
              SwitchListTile(
                  value: isVeg,
                  onChanged: (v) => setS(() => isVeg = v),
                  title: const Text('Vegetarian'),
                  activeColor: Colors.green,
                  contentPadding: EdgeInsets.zero),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final res = await ApiService.addItem({
                  'category_id': categoryId,
                  'name': nameC.text,
                  'price': double.tryParse(priceC.text) ?? 0,
                  'description': descC.text,
                  'is_veg': isVeg ? 1 : 0,
                  'is_available': 1,
                });
                // Upload image if picked
                if (pickedImage != null &&
                    res.data['success'] == true &&
                    res.data['data']?['id'] != null) {
                  final itemId = res.data['data']['id'] as int;
                  await ApiService.uploadMenuItemImage(
                      itemId, pickedImage!.path);
                }
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669)),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final nameC = TextEditingController(text: item['name'] ?? '');
    final priceC = TextEditingController(
        text: double.tryParse(item['price']?.toString() ?? '0')
                ?.toStringAsFixed(0) ??
            '0');
    final descC = TextEditingController(text: item['description'] ?? '');
    bool isVeg = (item['is_veg'] == 1 || item['is_veg'] == true);
    File? pickedImage;
    final itemId = int.parse(item['id'].toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Edit Menu Item'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Image preview / picker
              GestureDetector(
                onTap: () async {
                  final img = await ImagePicker()
                      .pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (img != null) setS(() => pickedImage = File(img.path));
                },
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: pickedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.file(pickedImage!, fit: BoxFit.cover))
                      : item['image_url'] != null &&
                              (item['image_url'] as String).isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: CachedNetworkImage(
                                imageUrl: item['image_url'],
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Center(
                                    child: CircularProgressIndicator()),
                                errorWidget: (_, __, ___) =>
                                    const Icon(Icons.broken_image),
                              ))
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 36, color: Colors.grey.shade400),
                                Text('Tap to change photo',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 13)),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: nameC,
                  decoration: const InputDecoration(
                      labelText: 'Name', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                  controller: priceC,
                  decoration: const InputDecoration(
                      labelText: 'Price (₹)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              TextField(
                  controller: descC,
                  decoration: const InputDecoration(
                      labelText: 'Description', border: OutlineInputBorder()),
                  maxLines: 2),
              const SizedBox(height: 6),
              SwitchListTile(
                  value: isVeg,
                  onChanged: (v) => setS(() => isVeg = v),
                  title: const Text('Vegetarian'),
                  activeColor: Colors.green,
                  contentPadding: EdgeInsets.zero),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await ApiService.updateItem(itemId, {
                  'name': nameC.text,
                  'price': double.tryParse(priceC.text) ?? 0,
                  'description': descC.text,
                  'is_veg': isVeg ? 1 : 0,
                  'is_available': item['is_available'] ?? 1,
                });
                if (pickedImage != null) {
                  await ApiService.uploadMenuItemImage(itemId, pickedImage!.path);
                }
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669)),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _editCategory(Map<String, dynamic> cat) async {
    final nameC = TextEditingController(text: cat['name'] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Category name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ApiService.updateCategory(int.parse(cat['id'].toString()), {'name': nameC.text});
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _deleteCategory(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Category'),
        content: const Text('Deleting this category will NOT delete the items in it. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.deleteCategory(id);
      _load();
    }
  }

  Future<void> _deleteItem(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiService.deleteItem(id);
        _load();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title:
            const Text('Menu', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: Color(0xFF059669)),
              onPressed: _addCategory),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF059669),
        onRefresh: _load,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF059669)))
            : _categories.isEmpty
                ? const Center(
                    child: Text('No categories. Tap + to add one.',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _categories.length,
                    itemBuilder: (_, ci) {
                      final cat = _categories[ci];
                      final items = List<Map<String, dynamic>>.from(
                          cat['items'] ?? []);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8)
                          ],
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 14, 8, 8),
                                child: Row(children: [
                                  Expanded(
                                      child: Text(cat['name'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16))),
                                  IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          color: Colors.blue, size: 18),
                                      onPressed: () => _editCategory(cat)),
                                  IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red, size: 18),
                                      onPressed: () => _deleteCategory(int.parse(cat['id'].toString()))),
                                  IconButton(
                                      icon: const Icon(Icons.add,
                                          color: Color(0xFF059669), size: 20),
                                      onPressed: () => _addItem(
                                          int.parse(cat['id'].toString()))),
                                ]),
                              ),
                              if (items.isEmpty)
                                const Padding(
                                    padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                                    child: Text('No items',
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 13))),
                              ...items.map((item) => _buildItemTile(item)),
                              const SizedBox(height: 4),
                            ]),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    final hasImage = item['image_url'] != null &&
        (item['image_url'] as String).isNotEmpty;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: hasImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: item['image_url'],
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.fastfood,
                        color: Colors.grey, size: 20)),
                errorWidget: (_, __, ___) => Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.fastfood,
                        color: Colors.grey, size: 20)),
              ))
          : Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: (item['is_veg'] == 1) ? Colors.green : Colors.red,
                    width: 1.5),
              ),
              child: Center(
                  child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: (item['is_veg'] == 1)
                              ? Colors.green
                              : Colors.red,
                          shape: BoxShape.circle)))),
      title: Text(item['name'] ?? '',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(
          '₹${double.tryParse(item['price']?.toString() ?? '0')?.toStringAsFixed(0)}',
          style: const TextStyle(
              color: Color(0xFF059669), fontWeight: FontWeight.bold)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            icon: Icon(Icons.edit_outlined,
                color: Colors.blue.shade300, size: 20),
            onPressed: () => _editItem(item)),
        IconButton(
            icon: Icon(Icons.delete_outline,
                color: Colors.red.shade300, size: 20),
            onPressed: () =>
                _deleteItem(int.parse(item['id'].toString()))),
      ]),
    );
  }
}
