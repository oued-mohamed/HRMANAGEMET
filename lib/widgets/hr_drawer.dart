import 'package:flutter/material.dart';

class HRDrawer extends StatelessWidget {
  const HRDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF000B58), // Deep navy blue
              Color(0xFF35BF8C), // Bright green
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: const Row(
                  children: [
                    Icon(
                      Icons.business_center,
                      color: Colors.white,
                      size: 30,
                    ),
                    SizedBox(width: 16),
                    Text(
                      'HR Pro',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Simple Menu Items
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dashboard, color: Colors.white),
                      title: const Text(
                        'Dashboard',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/manager-dashboard');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.people, color: Colors.white),
                      title: const Text(
                        'Gestion des employés',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/hr-employees');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.event_available,
                          color: Colors.white),
                      title: const Text(
                        'Gestion des congés',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/leave-management');
                      },
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.access_time, color: Colors.white),
                      title: const Text(
                        'Présence & temps',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Présence & temps'),
                            backgroundColor: Color(0xFF35BF8C),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.account_balance_wallet,
                          color: Colors.white),
                      title: const Text(
                        'Paie',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Paie'),
                            backgroundColor: Color(0xFF35BF8C),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Divider(color: Colors.white30),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.white70),
                      title: const Text(
                        'Déconnexion',
                        style: TextStyle(color: Colors.white70),
                      ),
                      onTap: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
