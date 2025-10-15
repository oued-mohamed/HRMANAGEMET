import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/company_provider.dart';
import '../data/models/company_model.dart';
import '../core/enums/user_role.dart';

class CompanySelectionScreen extends StatelessWidget {
  const CompanySelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final companies =
        ModalRoute.of(context)?.settings.arguments as List<CompanyModel>?;

    if (companies == null || companies.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('No Companies')),
        body: const Center(
          child: Text('No companies available'),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6B46C1),
              Color(0xFF10B981),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Header
                const Text(
                  'Select Company',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose your company to continue',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 40),

                // Company List
                Expanded(
                  child: ListView.builder(
                    itemCount: companies.length,
                    itemBuilder: (context, index) {
                      final company = companies[index];
                      return _buildCompanyCard(context, company);
                    },
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyCard(BuildContext context, CompanyModel company) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6B46C1), Color(0xFF10B981)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.business,
            color: Colors.white,
            size: 30,
          ),
        ),
        title: Text(
          company.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              company.employeeName,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getRoleColor(company.userRole).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getRoleColor(company.userRole).withOpacity(0.3),
                ),
              ),
              child: Text(
                company.userRole.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getRoleColor(company.userRole),
                ),
              ),
            ),
            if (company.jobTitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                company.jobTitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey,
          size: 16,
        ),
        onTap: () => _selectCompany(context, company),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.employee:
        return Colors.blue;
      case UserRole.hr:
        return Color(0xFF35BF8C);
      case UserRole.manager:
        return Colors.orange;
    }
  }

  void _selectCompany(BuildContext context, CompanyModel company) async {
    final authProvider = context.read<AuthProvider>();
    final companyProvider = context.read<CompanyProvider>();

    // Set current company
    await authProvider.setCurrentCompany(company);
    companyProvider.setCurrentCompany(company);

    // Navigate to appropriate dashboard
    switch (company.userRole) {
      case UserRole.employee:
        Navigator.pushReplacementNamed(context, '/employee-dashboard');
        break;
      case UserRole.hr:
        Navigator.pushReplacementNamed(context, '/hr-dashboard');
        break;
      case UserRole.manager:
        Navigator.pushReplacementNamed(context, '/manager-dashboard');
        break;
    }
  }
}
