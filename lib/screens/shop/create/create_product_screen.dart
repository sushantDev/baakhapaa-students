import 'dart:io';
import 'package:baakhapaa/models/product_draft.dart';
import 'package:baakhapaa/models/product_option_draft.dart';
import 'package:baakhapaa/models/product_variant.dart';
import 'package:baakhapaa/providers/vendor.dart';
import 'package:baakhapaa/utils/debug_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../widgets/skeleton_loading.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateProductScreen extends StatefulWidget {
  static const routeName = '/create-product';

  final int? productId; // 👈 needed for edit
  final ProductDraft? product;

  const CreateProductScreen({
    super.key,
    this.product,
    this.productId,
  });

  bool get isEdit => product != null;

  @override
  State<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  final _formKey = GlobalKey<FormState>();

  int _currentStep = 0; // 👈 STEP CONTROLLER

  final _titleCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _coinCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _vendorLinkCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  int? _selectedBrandId;
  int? _selectedCategoryId;
  // int? _selectedEpisodeId;
  bool _isLoadingRequirements = true;

  DateTime? _expiresAt;

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = []; // Newly picked images
  final List<String> _existingImageUrls = []; // Existing backend images

  late ProductDraft _draft; // 👈 IN-MEMORY DRAFT
  bool _isSubmitting = false;

  // Challenge mode tracking
  bool _isChallenge = false;
  int? _challengeId;
  bool _isInit = true;

  @override
  void initState() {
    super.initState();

    if (widget.isEdit) {
      final backendVariants = [...widget.product!.variants];

      // Debug: Verify backend data is populated
      if (kDebugMode) {
        DebugLogger.info(
            '🔍 Edit Mode - Total variants: ${backendVariants.length}');
        for (final v in backendVariants) {
          DebugLogger.info(
              '🔍 Variant backend values: ${v.backendOptionValues?.map((ov) => '${ov.optionName}:${ov.value}').join(', ')}');
        }
      }

      _draft = widget.product!.copyWith(
        options: _optionsFromBackendVariants(backendVariants),
        variants: backendVariants.map((v) {
          final rawImage = v.existingImageUrl;

          return v.copyWith(
            optionValues: v.backendOptionValues!
                .map((e) => '${e.optionName}:${e.value}')
                .toList(),
            existingImageUrl:
                rawImage != null ? rawImage.replaceFirst('storage/', '') : null,
          );
        }).toList(),
        images: [...widget.product!.images],
        existingImageUrls: [...(widget.product!.existingImageUrls ?? [])],
      );
    } else {
      // Initialize empty draft - will be updated in didChangeDependencies
      _draft = ProductDraft(
        title: '',
        qty: null,
        coin: null,
        price: null,
        brandId: null,
        categoryId: null,
        vendorLink: null,
        description: '',
        expiresAt: null,
        type: 'product',
        images: [],
        options: [],
        variants: [],
      );
    }

    _hydrateControllers();
    _loadRequirements();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Extract challenge arguments after widget tree is built
    if (_isInit && !widget.isEdit) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['isChallenge'] == true) {
        _isChallenge = true;
        _challengeId = args['challengeId'] as int?;
        final challengeCategoryId = args['categoryId'] as int?;

        // Update draft with challenge data and prefill category
        _draft = _draft.copyWith(
          isChallenge: _isChallenge,
          challengeId: _challengeId,
          categoryId: challengeCategoryId ?? _draft.categoryId,
        );

        // Set selected category for dropdown
        _selectedCategoryId = challengeCategoryId ?? _selectedCategoryId;
      }
      _isInit = false;
    }
  }

  // ───────────────── DRAFT PERSISTENCE ─────────────────
  List<ProductOptionDraft> _optionsFromBackendVariants(
    List<ProductVariant> variants,
  ) {
    final Map<String, Set<String>> map = {};

    for (final v in variants) {
      for (final ov in v.backendOptionValues ?? []) {
        map.putIfAbsent(ov.optionName, () => <String>{});
        map[ov.optionName]!.add(ov.value);
      }
    }

    return map.entries
        .map(
          (e) => ProductOptionDraft(
            name: e.key,
            values: e.value.toList(),
          ),
        )
        .toList();
  }

  void _hydrateControllers() {
    if (!widget.isEdit) return; // Only hydrate in edit mode

    _titleCtrl.text = _draft.title;
    _qtyCtrl.text = _draft.qty?.toString() ?? '';
    _coinCtrl.text = _draft.coin?.toString() ?? '';
    _priceCtrl.text = _draft.price?.toString() ?? '';
    _vendorLinkCtrl.text = _draft.vendorLink ?? '';
    _descCtrl.text = _draft.description ?? '';
    _expiresAt = _draft.expiresAt;

    // Handle existing images from backend
    if (_draft.existingImageUrls != null) {
      _existingImageUrls.addAll(_draft.existingImageUrls!);
    }
    // Handle newly picked images (if any)
    _images.addAll(_draft.images);

    _selectedBrandId = _draft.brandId;
    _selectedCategoryId = _draft.categoryId;
    // _selectedEpisodeId = _draft.episodeId;
  }

  void _saveStepOneToDraft() {
    _draft = _draft.copyWith(
      title: _titleCtrl.text.trim(),
      qty: int.tryParse(_qtyCtrl.text),
      coin: int.tryParse(_coinCtrl.text),
      price: int.tryParse(_priceCtrl.text),
      description: _descCtrl.text.trim(),
      expiresAt: _expiresAt,
    );
  }

  void _saveStepTwoToDraft() {
    _draft = _draft.copyWith(
      brandId: _selectedBrandId,
      categoryId: _selectedCategoryId,
      // episodeId: _selectedEpisodeId,
      vendorLink: _vendorLinkCtrl.text.trim().isEmpty
          ? null
          : _vendorLinkCtrl.text.trim(),
      images: _images,
      existingImageUrls: _existingImageUrls,
    );
  }

  void _saveStepThreeToDraft() {
    // Filter out empty variants (optional step)
    final validVariants = _draft.variants
        .where((v) =>
            v.price != null ||
            v.qty != null ||
            v.optionValues.isNotEmpty ||
            v.image != null)
        .toList();

    // Filter out empty options
    final validOptions = _draft.options
        .where((o) => o.name.isNotEmpty && o.values.isNotEmpty)
        .toList();

    _draft = _draft.copyWith(
      options: validOptions,
      variants: validVariants,
    );
  }

  Future<void> _loadRequirements() async {
    try {
      await context.read<Vendor>().fetchProductRequirements();
    } finally {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _isLoadingRequirements = false);
        }
      });
    }
  }

  // ───────────────── STEP NAVIGATION ─────────────────

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;
      if (_expiresAt == null) {
        // Set default expiry to tomorrow if not selected
        _expiresAt = DateTime.now().add(const Duration(days: 1));
      }
      _saveStepOneToDraft(); // ✅ SAVE BEFORE MOVING
    } else if (_currentStep == 1) {
      // Validate step 2 fields (Brand is mandatory)
      if (!_formKey.currentState!.validate()) return;

      // Validate step 2 (at least one image)
      if (_images.isEmpty && _existingImageUrls.isEmpty) {
        _error('At least one image required');
        return;
      }
      _saveStepTwoToDraft(); // ✅ SAVE STEP 2
    }
    setState(() => _currentStep++);
  }

  void _prevStep() {
    setState(() => _currentStep--);
  }

  // ───────────────── IMAGE PICKING ─────────────────

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isNotEmpty) {
      setState(() => _images.addAll(files));
    }
  }

  // ───────────────── SUBMIT ─────────────────

  Future<void> _submit() async {
    if (_isSubmitting) return;

    _saveStepThreeToDraft(); // ✅ SAVE STEP 3 (optional variants)
    final product = _draft;

    setState(() => _isSubmitting = true);

    try {
      final vendor = context.read<Vendor>();

      if (widget.isEdit) {
        await vendor.updateProduct(widget.productId!, product);
      } else {
        await vendor.createProduct(product);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit
              ? 'Product updated successfully'
              : 'Product created successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Save challenge-product mapping if this is a challenge product
      if (!widget.isEdit && _isChallenge && _challengeId != null) {
        // Note: Product ID should come from API response, but backend doesn't return it yet
        // For now, we'll save the challenge context to track participation
        await _saveChallengeProductContext(_challengeId!);
      }

      Future.delayed(const Duration(milliseconds: 400), () {
        Navigator.pop(context, true);
      });
    } catch (e) {
      // Extract clean error message
      String errorMsg = e.toString();

      // Remove "Exception: " prefix if present
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring('Exception: '.length);
      }

      // Log for debugging
      print('❌ Product submission error: $errorMsg');

      _error(errorMsg);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ───────────────── UI ─────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Product' : 'Create Product'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _stepIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _currentStep == 0
                    ? _buildStepOne()
                    : _currentStep == 1
                        ? _buildStepTwo()
                        : _buildStepThree(),
              ),
            ),
            _navigationButtons(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ───────────────── STEP 1 ─────────────────

  Widget _buildStepOne() {
    return Column(
      children: [
        _field(_titleCtrl, 'Title'),
        _field(_qtyCtrl, 'Quantity', isNum: true),
        _field(_coinCtrl, 'Coin', isNum: true, hint: '0'),
        _field(_priceCtrl, 'Price', isNum: true, hint: '0'),
        ListTile(
          title: Text(
            _expiresAt == null
                ? 'Select Expiry Date'
                : DateFormat('yyyy-MM-dd').format(_expiresAt!),
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _expiresAt ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2100),
            );
            if (d != null) setState(() => _expiresAt = d);
          },
        ),
        _field(_descCtrl, 'Description', max: 4),
      ],
    );
  }

  // ───────────────── STEP 2 ─────────────────

  Widget _buildStepTwo() {
    if (_isLoadingRequirements) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: ListSkeleton(itemCount: 5),
      );
    }

    final vendor = context.read<Vendor>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          isExpanded: true,
          value: _selectedBrandId,
          decoration: const InputDecoration(labelText: 'Brand'),
          validator: (v) => v == null ? 'Required' : null,
          items: vendor.brands
              .map((b) => DropdownMenuItem(
                    value: b['id'] as int,
                    child: Text(b['title'] as String),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedBrandId = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          isExpanded: true,
          value: _selectedCategoryId,
          decoration: const InputDecoration(labelText: 'Category (Optional)'),
          items: vendor.categories
              .map((c) => DropdownMenuItem(
                    value: c['id'] as int,
                    child: Text(c['title'] as String),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedCategoryId = v),
        ),
        const SizedBox(height: 12),
        // DropdownButtonFormField<int>(
        //   isExpanded: true,
        //   value: _selectedEpisodeId,
        //   decoration: const InputDecoration(labelText: 'Episode (Optional)'),
        //   items: vendor.episodes
        //       .map((e) => DropdownMenuItem(
        //             value: e['id'] as int,
        //             child: Text(e['title'] as String),
        //           ))
        //       .toList(),
        //   onChanged: (v) => setState(() => _selectedEpisodeId = v),
        // ),
        const SizedBox(height: 12),
        _field(_vendorLinkCtrl, 'Vendor Link', required: false),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Display existing images from backend
            ..._existingImageUrls.map((url) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      'https://app.baakhapaa.com/storage/$url',
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 90,
                        height: 90,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _existingImageUrls.remove(url)),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
            // Display newly picked images
            ..._images.map((img) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(img.path),
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _images.remove(img)),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
        TextButton.icon(
          onPressed: _pickImages,
          icon: const Icon(Icons.add),
          label: const Text('Add Images'),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ───────────────── STEP 3 ─────────────────

  Widget _buildStepThree() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Options & Variants',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        // ───────────────── OPTIONS BUILDER ─────────────────
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _draft.options.length,
          itemBuilder: (_, index) {
            final option = _draft.options[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Option Name
                    TextFormField(
                      initialValue: option.name,
                      decoration: const InputDecoration(
                        labelText: 'Option name (e.g. Size, Color, Length)',
                      ),
                      onChanged: (v) {
                        option.name = v;
                        _generateVariants();
                      },
                    ),
                    const SizedBox(height: 8),
                    // Option Values (Chips)
                    if (option.values.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: option.values.map((v) {
                          return Chip(
                            label: Text(v),
                            onDeleted: () {
                              setState(() {
                                option.values.remove(v);
                                _generateVariants();
                              });
                            },
                          );
                        }).toList(),
                      ),
                    // Add Value Button
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add value'),
                      onPressed: () async {
                        final value = await _askForValue();
                        if (value != null && value.isNotEmpty) {
                          setState(() {
                            option.values.add(value);
                            _generateVariants();
                          });
                        }
                      },
                    ),
                    // Delete Option Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _draft.options.removeAt(index);
                            _generateVariants();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Add Option Button
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Option'),
            onPressed: () {
              setState(() {
                _draft.options.add(ProductOptionDraft());
              });
            },
          ),
        ),
        const SizedBox(height: 24),
        // ───────────────── VARIANTS (AUTO-GENERATED) ─────────────────
        if (_draft.variants.isNotEmpty) ...[
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Generated Variants',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _draft.variants.length,
            itemBuilder: (_, i) {
              final v = _draft.variants[i];

              // 🔥 Initialize controllers with existing variant data
              final priceController = TextEditingController(
                text: v.price?.toString() ?? '',
              );
              final qtyController = TextEditingController(
                text: v.qty?.toString() ?? '',
              );

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.optionValues
                            .map((ov) => ov.split(':').last)
                            .join(' / '),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: priceController, // 🔥 Use controller
                              decoration:
                                  const InputDecoration(labelText: 'Price'),
                              keyboardType: TextInputType.number,
                              onChanged: (val) => v.price = int.tryParse(val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: qtyController, // 🔥 Use controller
                              decoration:
                                  const InputDecoration(labelText: 'Qty'),
                              keyboardType: TextInputType.number,
                              onChanged: (val) => v.qty = int.tryParse(val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // 🔥 Show new image OR existing image from backend
                          if (v.image != null)
                            Image.file(
                              File(v.image!.path),
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            )
                          else if (v.existingImageUrl != null)
                            Image.network(
                              'https://app.baakhapaa.com/storage/${v.existingImageUrl}',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image, size: 60),
                            )
                          else
                            const SizedBox(width: 60, height: 60),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.image),
                            label: Text(
                              v.image != null || v.existingImageUrl != null
                                  ? 'Change Image'
                                  : 'Pick Image',
                            ),
                            onPressed: () async {
                              final picked = await _picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85);
                              if (picked != null) {
                                setState(() => v.image = picked);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  // ───────────────── VARIANT AUTO-GENERATION ─────────────────

  void _generateVariants() {
    final options = _draft.options
        .where((o) => o.name.isNotEmpty && o.values.isNotEmpty)
        .toList();

    if (options.isEmpty) {
      setState(() {
        _draft = _draft.copyWith(variants: []);
      });
      return;
    }

    // Generate all combinations with "OptionName:Value" format
    List<List<String>> combos = [[]];

    for (final option in options) {
      final next = <List<String>>[];
      for (final combo in combos) {
        for (final value in option.values) {
          next.add([...combo, '${option.name}:$value']);
        }
      }
      combos = next;
    }

    final oldVariants = _draft.variants;

    final newVariants = combos.map((combo) {
      final existing = oldVariants.firstWhere(
        (v) => _sameOptions(v.optionValues, combo),
        orElse: () => ProductVariant(
          optionValues: combo,
          price: _draft.price,
          qty: 0,
        ),
      );

      return existing.copyWith(optionValues: combo);
    }).toList();

    setState(() {
      _draft = _draft.copyWith(variants: newVariants);
    });
  }

  bool _sameOptions(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (final v in a) {
      if (!b.contains(v)) return false;
    }
    return true;
  }

  // ───────────────── CHALLENGE PRODUCT MAPPING ─────────────────

  /// Save challenge-product context to local storage
  /// Similar to how season challenges are tracked
  Future<void> _saveChallengeProductContext(int challengeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> ids =
          prefs.getStringList('challenge_product_ids') ?? [];

      // Store challenge ID to mark participation
      final challengeKey = 'challenge_$challengeId';
      if (!ids.contains(challengeKey)) {
        ids.add(challengeKey);
        await prefs.setStringList('challenge_product_ids', ids);
        DebugLogger.info(
            '💾 Saved challenge product context for challenge: $challengeId');
      }
    } catch (e) {
      DebugLogger.error('Error saving challenge product context: $e');
    }
  }

  // ───────────────── ADD VALUE DIALOG ─────────────────

  Future<String?> _askForValue() async {
    String temp = '';
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add value'),
        content: TextField(
          onChanged: (v) => temp = v,
          decoration: const InputDecoration(
            hintText: 'e.g. Small, Medium, Red, etc.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, temp.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ───────────────── NAVIGATION ─────────────────

  Widget _navigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentStep > 0)
            ElevatedButton(onPressed: _prevStep, child: const Text('Back')),
          const Spacer(),
          ElevatedButton(
            onPressed: _currentStep < 2 ? _nextStep : _submit,
            child: Text(_currentStep < 2 ? 'Next' : 'Submit',
                style: const TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
  }

  Widget _stepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _stepSegment(
            title: 'Product Info',
            active: _currentStep == 0,
            completed: _currentStep > 0,
          ),
          const SizedBox(width: 8),
          _stepSegment(
            title: 'Media & Brand',
            active: _currentStep == 1,
            completed: _currentStep > 1,
          ),
          const SizedBox(width: 8),
          _stepSegment(
            title: 'Variants',
            active: _currentStep == 2,
            completed: false,
          ),
        ],
      ),
    );
  }

  Widget _stepSegment({
    required String title,
    required bool active,
    required bool completed,
  }) {
    final color = completed || active ? Colors.amber : Colors.grey.shade300;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: active || completed ? Colors.white : Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool isNum = false,
    int max = 1,
    bool required = true,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: max,
        keyboardType: isNum ? TextInputType.number : null,
        validator: (v) {
          if (!required) return null;
          if (v == null || v.trim().isEmpty) return 'Required';
          if (isNum && int.tryParse(v) == null) return 'Enter a valid number';
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
