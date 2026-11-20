import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/navigation_provider.dart';
import '../widgets/floor_plan_view.dart';
import '../models/nav_data.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = Provider.of<NavigationProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("IndoorNav", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        Text("PRO VERSION 1.0", style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 2)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.green.withOpacity(0.05),
                      ),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.wifi, size: 12, color: Colors.green),
                          SizedBox(width: 4),
                          Text("CONNECTED", style: TextStyle(color: Colors.green, fontSize: 10)),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 32),

                // Destination Selector
                const Text("SELECT DESTINATION", style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: DropdownButtonFormField<int>(
                    value: nav.destination,
                    dropdownColor: const Color(0xFF1A1A1A),
                    decoration: const InputDecoration(border: InputBorder.none),
                    hint: const Text("Choose a room...", style: TextStyle(color: Colors.grey)),
                    style: const TextStyle(color: Colors.white),
                    items: NavData.nodeNames.entries.map((entry) {
                      return DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) nav.setDestination(val);
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // Status Cards
                Row(
                  children: [
                    _buildStatusCard("CURRENT NODE", nav.currentNode?.toString() ?? "--", LucideIcons.mapPin, Colors.green),
                    const SizedBox(width: 16),
                    _buildStatusCard("NEXT NODE", nav.nextNode?.toString() ?? "--", LucideIcons.arrowRight, Colors.blue),
                  ],
                ),
                const SizedBox(height: 32),

                // Floor Plan Header & Switcher
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("FLOOR PLAN", style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1)),
                    Row(
                      children: [
                        _buildFloorButton("GROUND", 0, nav),
                        const SizedBox(width: 8),
                        _buildFloorButton("FIRST", 1, nav),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FloorPlanView(
                  path: nav.path.map((e) => e.id).toList(),
                  currentNode: nav.currentNode,
                  nextNode: nav.nextNode,
                  selectedFloor: nav.selectedFloor,
                ),
                const SizedBox(height: 32),

                // Path Visualization
                if (nav.path.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("FULL PATH", style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1)),
                      if (nav.progressIndex > 0)
                        TextButton.icon(
                          onPressed: nav.undoReached,
                          icon: const Icon(LucideIcons.undo, size: 12, color: Colors.blue),
                          label: const Text("UNDO", style: TextStyle(color: Colors.blue, fontSize: 10)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: nav.path.length,
                      separatorBuilder: (context, index) => Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey.withOpacity(0.3)),
                      itemBuilder: (context, index) {
                        final step = nav.path[index];
                        final isReached = index <= nav.progressIndex;
                        final isNext = index == nav.progressIndex + 1;
                        
                        return GestureDetector(
                          onTap: isNext ? nav.markReached : null,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isReached ? Colors.green.withOpacity(0.2) : (isNext ? Colors.blue.withOpacity(0.2) : const Color(0xFF1A1A1A)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isReached ? Colors.green : (isNext ? Colors.blue : Colors.white.withOpacity(0.05)),
                                width: isNext ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  step.roomNumber,
                                  style: TextStyle(
                                    color: isReached ? Colors.green : (isNext ? Colors.blue : Colors.white),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  step.name,
                                  style: TextStyle(
                                    color: isReached ? Colors.green.withOpacity(0.7) : (isNext ? Colors.blue.withOpacity(0.7) : Colors.grey),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // Instruction Panel
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151515),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.navigation, size: 48, color: Colors.green.withOpacity(0.2)),
                      const SizedBox(height: 24),
                      if (nav.isLoading)
                        const CircularProgressIndicator(color: Colors.green)
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            nav.instruction,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300),
                          ),
                        ),
                    ],
                  ),
                ).animate().scale(delay: 200.ms),

                // Footer Button
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 64),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.camera),
                      SizedBox(width: 12),
                      Text("START SCAN", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildFloorButton(String label, int floor, NavigationProvider nav) {
    final isSelected = nav.selectedFloor == floor;
    return GestureDetector(
      onTap: () => nav.setFloor(floor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.green : Colors.grey.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
