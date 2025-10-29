import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';
import 'dart:typed_data';
import '../services/odoo_service.dart';
import '../widgets/employee_drawer.dart';
import '../presentation/providers/language_provider.dart';

class ExpenseReportsScreen extends StatefulWidget {
  const ExpenseReportsScreen({super.key});

  @override
  State<ExpenseReportsScreen> createState() => _ExpenseReportsScreenState();
}

class _ExpenseReportsScreenState extends State<ExpenseReportsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final OdooService _odooService = OdooService();
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;
  String _filterState =
      'all'; // 'all', 'draft', 'reported', 'approved', 'done', 'refused'

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      final expenses = await _odooService.getEmployeeExpenses();
      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading expenses: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredExpenses {
    if (_filterState == 'all') return _expenses;
    return _expenses.where((expense) {
      final state = expense['state']?.toString() ?? '';
      return state == _filterState;
    }).toList();
  }

  double get _totalAmount {
    return _filteredExpenses.fold(0.0, (sum, expense) {
      final amount = expense['total_amount'];
      if (amount is double) return sum + amount;
      if (amount is int) return sum + amount.toDouble();
      return sum;
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr == false) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr.toString();
    }
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0.00';
    if (amount is double) return amount.toStringAsFixed(2);
    if (amount is int) return amount.toStringAsFixed(2);
    return amount.toString();
  }

  String _getStateLabel(String? state) {
    switch (state) {
      case 'draft':
        return 'Brouillon';
      case 'reported':
        return 'Rapporté';
      case 'approved':
        return 'Approuvé';
      case 'done':
        return 'Payé';
      case 'refused':
        return 'Refusé';
      default:
        return 'Inconnu';
    }
  }

  Color _getStateColor(String? state) {
    switch (state) {
      case 'draft':
        return Colors.orange;
      case 'reported':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'done':
        return const Color(0xFF35BF8C);
      case 'refused':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentMode(String? mode) {
    if (mode == null) return 'N/A';
    // Map Odoo payment modes to French labels
    switch (mode.toLowerCase()) {
      case 'own_account':
        return 'Employé (à rembourser)';
      case 'company_account':
        return 'Société';
      default:
        return mode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const EmployeeDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF000B58), // Deep navy blue
              Color(0xFF35BF8C), // Teal green
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                margin: EdgeInsets.fromLTRB(
                  isDesktop ? 32 : 20,
                  20,
                  isDesktop ? 32 : 20,
                  0,
                ),
                padding: EdgeInsets.all(isDesktop ? 24 : 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Menu Button
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF000B58).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                        icon: const Icon(
                          Icons.menu,
                          color: Color(0xFF000B58),
                          size: 24,
                        ),
                      ),
                    ),
                    SizedBox(width: isDesktop ? 20 : 16),
                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mes notes de frais',
                            style: TextStyle(
                              fontSize: isDesktop ? 28 : 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF000B58),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_filteredExpenses.length} ${_filteredExpenses.length == 1 ? 'note' : 'notes'}',
                            style: TextStyle(
                              fontSize: isDesktop ? 16 : 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Refresh Button
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF35BF8C).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: _loadExpenses,
                        icon: const Icon(
                          Icons.refresh,
                          color: Color(0xFF35BF8C),
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Summary Card
              Container(
                margin: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
                padding: EdgeInsets.all(isDesktop ? 24 : 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${_formatAmount(_totalAmount)} DH',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF000B58),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[300],
                    ),
                    Column(
                      children: [
                        Text(
                          '${_filteredExpenses.length}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF35BF8C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Notes',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Filter Buttons
              Container(
                margin: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Tous', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Brouillon', 'draft'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Rapporté', 'reported'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Approuvé', 'approved'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Payé', 'done'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Refusé', 'refused'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Expenses List
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredExpenses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 80,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Aucune note de frais',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadExpenses,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredExpenses.length,
                                itemBuilder: (context, index) {
                                  final expense = _filteredExpenses[index];
                                  return _buildExpenseCard(expense);
                                },
                              ),
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateExpenseDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle note'),
        backgroundColor: const Color(0xFF35BF8C),
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showCreateExpenseDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedPaymentMode = 'own_account';
    XFile? selectedImage;
    PlatformFile? selectedFile;
    final ImagePicker _imagePicker = ImagePicker();
    final categoriesFuture = _odooService.getExpenseCategories();
    int? selectedCategoryId;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.add_circle, color: Color(0xFF35BF8C)),
                  SizedBox(width: 8),
                  Text('Nouvelle note de frais'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    const Text(
                      'Description *',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2d3436),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Ex: Déjeuner, Transport...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF35BF8C)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    const Text(
                      'Montant (DH) *',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2d3436),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF35BF8C)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category
                    const Text(
                      'Catégorie *',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2d3436),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: categoriesFuture,
                      builder: (context, snapshot) {
                        // Capture selectedCategoryId for this build
                        final currentCategoryId = selectedCategoryId;
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (snapshot.hasError ||
                            !snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              snapshot.hasError
                                  ? 'Erreur lors du chargement'
                                  : 'Aucune catégorie disponible',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }

                        final categories = snapshot.data!;
                        return DropdownButtonFormField<int>(
                          value: currentCategoryId,
                          decoration: InputDecoration(
                            hintText: 'Sélectionner une catégorie',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFF35BF8C)),
                            ),
                          ),
                          items: categories.map((category) {
                            final categoryId = category['id'] as int;
                            final categoryName =
                                category['name']?.toString() ?? 'Inconnu';
                            return DropdownMenuItem<int>(
                              value: categoryId,
                              child: Text(categoryName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedCategoryId = value;
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date
                    const Text(
                      'Date *',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2d3436),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final languageProvider = Provider.of<LanguageProvider>(
                            context,
                            listen: false);
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          locale: languageProvider.locale,
                        );
                        if (date != null) {
                          setDialogState(() {
                            selectedDate = date;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: Color(0xFF35BF8C)),
                            const SizedBox(width: 8),
                            Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Payment Mode
                    const Text(
                      'Payé par',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2d3436),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedPaymentMode,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF35BF8C)),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'own_account',
                          child: Text('Employé (à rembourser)'),
                        ),
                        DropdownMenuItem(
                          value: 'company_account',
                          child: Text('Société'),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedPaymentMode = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description (optional)
                    const Text(
                      'Notes internes (optionnel)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2d3436),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Ajouter des détails...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF35BF8C)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // File Upload Section
                    const Text(
                      'Justificatif (optionnel)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2d3436),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          if (selectedImage != null || selectedFile != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Icon(
                                    selectedImage != null
                                        ? Icons.image
                                        : Icons.insert_drive_file,
                                    color: const Color(0xFF35BF8C),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedImage?.name ??
                                          selectedFile?.name ??
                                          'Fichier sélectionné',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () {
                                      setDialogState(() {
                                        selectedImage = null;
                                        selectedFile = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          if (selectedImage == null && selectedFile == null)
                            InkWell(
                              onTap: () async {
                                // Show options: Camera, Gallery, or File
                                final option =
                                    await showModalBottomSheet<String>(
                                  context: context,
                                  builder: (context) => Container(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.camera_alt,
                                              color: Color(0xFF35BF8C)),
                                          title: const Text('Appareil photo'),
                                          onTap: () =>
                                              Navigator.pop(context, 'camera'),
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.photo,
                                              color: Color(0xFF35BF8C)),
                                          title: const Text('Galerie photos'),
                                          onTap: () =>
                                              Navigator.pop(context, 'gallery'),
                                        ),
                                        ListTile(
                                          leading: const Icon(
                                              Icons.insert_drive_file,
                                              color: Color(0xFF35BF8C)),
                                          title: const Text(
                                              'Sélectionner un fichier'),
                                          onTap: () =>
                                              Navigator.pop(context, 'file'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );

                                if (option == null) return;

                                if (option == 'camera') {
                                  final image = await _imagePicker.pickImage(
                                    source: ImageSource.camera,
                                    maxWidth:
                                        1024, // Reduced for web compatibility
                                    maxHeight:
                                        1024, // Reduced for web compatibility
                                    imageQuality:
                                        50, // Much lower quality for smaller size
                                  );
                                  if (image != null) {
                                    setDialogState(() {
                                      selectedImage = image;
                                      selectedFile = null;
                                    });
                                  }
                                } else if (option == 'gallery') {
                                  final image = await _imagePicker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth:
                                        1024, // Reduced for web compatibility
                                    maxHeight:
                                        1024, // Reduced for web compatibility
                                    imageQuality:
                                        50, // Much lower quality for smaller size
                                  );
                                  if (image != null) {
                                    setDialogState(() {
                                      selectedImage = image;
                                      selectedFile = null;
                                    });
                                  }
                                } else if (option == 'file') {
                                  final result =
                                      await FilePicker.platform.pickFiles();
                                  if (result != null &&
                                      result.files.isNotEmpty) {
                                    setDialogState(() {
                                      selectedFile = result.files.single;
                                      selectedImage = null;
                                    });
                                  }
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cloud_upload_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Ajouter un justificatif',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF2d3436),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Appuyez pour sélectionner',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Annuler',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty ||
                        amountController.text.trim().isEmpty ||
                        selectedCategoryId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Veuillez remplir tous les champs obligatoires'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    try {
                      final amount = double.parse(amountController.text.trim());
                      await _createExpense(
                        name: nameController.text.trim(),
                        amount: amount,
                        date: selectedDate,
                        paymentMode: selectedPaymentMode,
                        productId: selectedCategoryId,
                        description: descriptionController.text.trim(),
                        imageFile: selectedImage,
                        file: selectedFile,
                      );
                      Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF35BF8C),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createExpense({
    required String name,
    required double amount,
    required DateTime date,
    required String paymentMode,
    required int? productId,
    required String description,
    XFile? imageFile,
    PlatformFile? file,
  }) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Création de la note de frais...'),
            ],
          ),
          backgroundColor: Color(0xFF000B58),
        ),
      );

      // Create expense in Odoo using the service method
      final expenseId = await _odooService.createExpense(
        name: name,
        totalAmount: amount,
        date: date,
        paymentMode: paymentMode,
        productId: productId,
        description: description.isNotEmpty ? description : null,
      );

      print('✅ Expense created with ID: $expenseId');

      // Upload file if provided
      if (imageFile != null) {
        try {
          print('📸 Compressing image before upload...');
          final compressedBytes = await _compressImage(imageFile);
          final finalSize = compressedBytes.length;

          print(
              '📊 Original size: ${(await imageFile.readAsBytes()).length / 1024} KB');
          print('📊 Compressed size: ${finalSize / 1024} KB');

          // Check if image is too large (>800KB) before attempting upload
          if (finalSize > 800 * 1024) {
            throw Exception(
                'L\'image est trop volumineuse (${(finalSize / 1024).toStringAsFixed(0)} KB). '
                'La taille maximale acceptée est de 800 KB. Veuillez sélectionner une image plus petite.');
          }

          await _odooService.uploadAttachment(
            filename: imageFile.name,
            fileBytes: compressedBytes,
            resModel: 'hr.expense',
            resId: expenseId,
          );
          print('✅ Image uploaded successfully');
        } catch (e) {
          print('⚠️ Error uploading image: $e');

          // Show user-friendly error message
          final errorMessage = e.toString().contains('trop volumineuse')
              ? e.toString().replaceFirst('Exception: ', '')
              : (e.toString().contains('413') ||
                      e.toString().contains('Request Entity Too Large'))
                  ? 'L\'image est trop volumineuse pour être téléchargée. Veuillez sélectionner une image plus petite (moins de 800 KB).'
                  : 'Erreur lors du téléchargement de l\'image: ${e.toString().replaceFirst('Exception: ', '').replaceFirst('RPC call failed: 413 - ', '')}';

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } else if (file != null && file.bytes != null) {
        try {
          List<int> fileBytes = file.bytes!;
          String filename = file.name;

          // Check if it's an image file and compress if needed
          if (file.extension != null) {
            final ext = file.extension!.toLowerCase();
            if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') {
              print('🖼️ Compressing image file before upload...');
              print('📊 Original size: ${fileBytes.length / 1024} KB');

              // Compress from bytes (PlatformFile doesn't have a File path)
              final compressedBytes =
                  await _compressImageFromBytes(fileBytes, ext);
              if (compressedBytes.isNotEmpty &&
                  compressedBytes.length < fileBytes.length) {
                fileBytes = compressedBytes;
                print('📊 Compressed size: ${fileBytes.length / 1024} KB');
              }
            }
          }

          // Detect MIME type from extension
          String? mimetype;
          if (file.extension != null) {
            final ext = file.extension!.toLowerCase();
            switch (ext) {
              case 'jpg':
              case 'jpeg':
                mimetype = 'image/jpeg';
                break;
              case 'png':
                mimetype = 'image/png';
                break;
              case 'pdf':
                mimetype = 'application/pdf';
                break;
              default:
                mimetype = null;
            }
          }
          await _odooService.uploadAttachment(
            filename: filename,
            fileBytes: fileBytes,
            resModel: 'hr.expense',
            resId: expenseId,
            mimetype: mimetype,
          );
          print('✅ File uploaded successfully');
        } catch (e) {
          print('⚠️ Error uploading file: $e');
          // Don't fail the whole operation if file upload fails
        }
      }

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Note de frais créée avec succès'),
            ],
          ),
          backgroundColor: Color(0xFF35BF8C),
          duration: Duration(seconds: 3),
        ),
      );

      // Refresh the list
      _loadExpenses();
    } catch (e) {
      print('❌ Error creating expense: $e');
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la création: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Compress an image from XFile
  Future<List<int>> _compressImage(XFile imageFile) async {
    try {
      // Read bytes first
      final originalBytes = await imageFile.readAsBytes();
      final originalSize = originalBytes.length;
      print(
          '📏 Original file size: ${(originalSize / 1024).toStringAsFixed(2)} KB');

      // If file is already small (< 300KB), return as is
      if (originalSize < 300 * 1024) {
        print('📦 File is small enough, skipping compression');
        return originalBytes;
      }

      // On Web, flutter_image_compress doesn't work (UnimplementedError)
      // The image should already be compressed by image_picker
      // Check if it's too large and warn/return
      if (kIsWeb) {
        print('🌐 Web detected - flutter_image_compress not supported on web');
        print(
            '⚠️ Image already compressed by image_picker: ${(originalSize / 1024).toStringAsFixed(2)} KB');

        // If image is still too large (>800KB), it will likely fail upload
        // But we can't compress it further on web, so just return it and let the upload fail
        if (originalSize > 800 * 1024) {
          print(
              '❌ Image is too large (>800KB) for upload. Please select a smaller image.');
        }
        return originalBytes;
      }

      // On mobile/desktop, try with file path first
      try {
        final file = File(imageFile.path);
        if (await file.exists()) {
          final outputFormat = imageFile.path.toLowerCase().endsWith('.png')
              ? CompressFormat.png
              : CompressFormat.jpeg;

          final result = await FlutterImageCompress.compressWithFile(
            file.absolute.path,
            minWidth: 1600,
            minHeight: 1200,
            quality: 70,
            format: outputFormat,
          );

          if (result != null && result.isNotEmpty) {
            print(
                '✅ Compression successful: ${(result.length / 1024).toStringAsFixed(2)} KB');
            return result;
          }
        }
      } catch (fileError) {
        print('⚠️ File compression failed: $fileError, trying with bytes...');
      }

      // Fallback: compress with bytes (works on all platforms)
      final result = await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: 1600,
        minHeight: 1200,
        quality: 70,
        format: imageFile.path.toLowerCase().endsWith('.png')
            ? CompressFormat.png
            : CompressFormat.jpeg,
      );

      if (result.isNotEmpty) {
        print(
            '✅ Compression successful (bytes): ${(result.length / 1024).toStringAsFixed(2)} KB');
        return result;
      }

      // If all compression fails, return original but warn
      print(
          '⚠️ All compression methods failed, returning original (may be too large)');
      return originalBytes;
    } catch (e) {
      print('⚠️ Error compressing image: $e');
      // If compression fails, return original
      try {
        return await imageFile.readAsBytes();
      } catch (readError) {
        print('❌ Failed to read image file: $readError');
        rethrow;
      }
    }
  }

  /// Compress image from bytes (for PlatformFile)
  Future<List<int>> _compressImageFromBytes(
      List<int> bytes, String? extension) async {
    try {
      if (bytes.length < 300 * 1024) {
        print('📦 File is small enough, skipping compression');
        return bytes;
      }

      final outputFormat = (extension?.toLowerCase() == 'png')
          ? CompressFormat.png
          : CompressFormat.jpeg;

      // Use compressWithList which works on all platforms including web
      final result = await FlutterImageCompress.compressWithList(
        Uint8List.fromList(bytes),
        minWidth: 1600,
        minHeight: 1200,
        quality: 70,
        format: outputFormat,
      );

      if (result.isNotEmpty) {
        print(
            '✅ Compression successful (from bytes): ${(result.length / 1024).toStringAsFixed(2)} KB');
        return result;
      }

      // If compression fails and still too large, try with even more aggressive settings
      if (bytes.length > 500 * 1024) {
        print(
            '⚠️ First compression failed, trying more aggressive compression...');
        final aggressiveResult = await FlutterImageCompress.compressWithList(
          Uint8List.fromList(bytes),
          minWidth: 1280,
          minHeight: 960,
          quality: 60,
          format: outputFormat,
        );

        if (aggressiveResult.isNotEmpty) {
          print(
              '✅ Aggressive compression successful: ${(aggressiveResult.length / 1024).toStringAsFixed(2)} KB');
          return aggressiveResult;
        }
      }

      print(
          '⚠️ Compression failed, returning original (may be too large for upload)');
      return bytes; // Return original if compression fails
    } catch (e) {
      print('⚠️ Error compressing image from bytes: $e');
      return bytes; // Return original if compression fails
    }
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterState == value;
    return GestureDetector(
      onTap: () => setState(() => _filterState = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF35BF8C) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense) {
    final name = expense['name']?.toString() ?? 'Sans description';
    final date = _formatDate(expense['date']?.toString());
    final amount = _formatAmount(expense['total_amount']);
    final state = expense['state']?.toString();
    final paymentMode = _getPaymentMode(expense['payment_mode']?.toString());
    final description = expense['description']?.toString() ?? '';
    final product = expense['product_id'] is List
        ? expense['product_id'][1].toString()
        : 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _showExpenseDetails(expense),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getStateColor(state).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: _getStateColor(state),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title and Date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF2d3436),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Amount and Status
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$amount DH',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF000B58),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStateColor(state).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getStateLabel(state),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getStateColor(state),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.category,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    product,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.payment,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      paymentMode,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExpenseDetails(Map<String, dynamic> expense) {
    final name = expense['name']?.toString() ?? 'Sans description';
    final date = _formatDate(expense['date']?.toString());
    final amount = _formatAmount(expense['total_amount']);
    final state = expense['state']?.toString();
    final paymentMode = _getPaymentMode(expense['payment_mode']?.toString());
    final description = expense['description']?.toString() ?? '';
    final product = expense['product_id'] is List
        ? expense['product_id'][1].toString()
        : 'N/A';
    final quantity = expense['quantity'] ?? 1;
    final priceUnit = _formatAmount(expense['price_unit']);
    final taxAmount = _formatAmount(expense['tax_amount']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long,
                      size: 32, color: Color(0xFF000B58)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF000B58),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStateColor(state).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStateLabel(state),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getStateColor(state),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                        'Montant total', '$amount DH', Colors.orange),
                    const SizedBox(height: 16),
                    _buildDetailRow('Date', date, Colors.blue),
                    const SizedBox(height: 16),
                    _buildDetailRow('Catégorie', product, Colors.green),
                    const SizedBox(height: 16),
                    _buildDetailRow('Payé par', paymentMode, Colors.purple),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                        'Quantité', quantity.toString(), Colors.teal),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                        'Prix unitaire', '$priceUnit DH', Colors.indigo),
                    if (taxAmount != '0.00') ...[
                      const SizedBox(height: 16),
                      _buildDetailRow('Taxe', '$taxAmount DH', Colors.red),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2d3436),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Delete button (only for draft expenses)
            if (state == 'draft')
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close detail modal first
                    _confirmDeleteExpense(expense);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer cette note de frais'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteExpense(Map<String, dynamic> expense) {
    final expenseId = expense['id'] as int;
    final expenseName = expense['name']?.toString() ?? 'cette note de frais';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Confirmer la suppression',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              'Êtes-vous sûr de vouloir supprimer "$expenseName" ?\n\nCette action est irréversible.',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                minimumSize: const Size(0, 40),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close confirmation dialog
                await _deleteExpense(expenseId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteExpense(int expenseId) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Suppression en cours...'),
            ],
          ),
          backgroundColor: Color(0xFF000B58),
        ),
      );

      final success = await _odooService.deleteExpense(expenseId);

      if (success) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Note de frais supprimée avec succès'),
              ],
            ),
            backgroundColor: Color(0xFF35BF8C),
            duration: Duration(seconds: 3),
          ),
        );

        // Refresh the list
        _loadExpenses();
      } else {
        throw Exception('La suppression a échoué');
      }
    } catch (e) {
      print('❌ Error deleting expense: $e');
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Erreur lors de la suppression: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2d3436),
          ),
        ),
      ],
    );
  }
}
