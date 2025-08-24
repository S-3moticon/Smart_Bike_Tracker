import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

import '../controllers/home_controller.dart';
import '../widgets/device_connection_card.dart';
import '../widgets/location_tracking_view.dart';
import '../widgets/gps_history_view.dart';
import 'settings_screen.dart';

/// Optimized Home Screen with improved separation of concerns
class HomeScreenOptimized extends StatefulWidget {
  const HomeScreenOptimized({super.key});

  @override
  State<HomeScreenOptimized> createState() => _HomeScreenOptimizedState();
}

class _HomeScreenOptimizedState extends State<HomeScreenOptimized> 
    with SingleTickerProviderStateMixin {
  late final HomeController _controller;
  late final TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _controller = HomeController(
      onStateChanged: () => setState(() {}),
      context: context,
    );
    _controller.initialize();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildConnectionStatus(),
          _buildTabBar(),
          Expanded(child: _buildTabContent()),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Smart Bike Tracker'),
      centerTitle: true,
      actions: [
        // Settings button
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _navigateToSettings(),
        ),
        // Bluetooth indicator
        StreamBuilder<BluetoothAdapterState>(
          stream: _controller.bluetoothState,
          builder: (context, snapshot) {
            final state = snapshot.data ?? BluetoothAdapterState.unknown;
            return IconButton(
              icon: Icon(
                state == BluetoothAdapterState.on 
                  ? Icons.bluetooth 
                  : Icons.bluetooth_disabled,
                color: state == BluetoothAdapterState.on 
                  ? Colors.blue 
                  : Colors.grey,
              ),
              onPressed: state == BluetoothAdapterState.off 
                ? () => _controller.promptBluetoothEnable(context)
                : null,
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildConnectionStatus() {
    return DeviceConnectionCard(
      connectionState: _controller.connectionState,
      currentDevice: _controller.connectedDevice,
      deviceStatus: _controller.deviceStatus,
      isScanning: _controller.isScanning,
      availableDevices: _controller.availableDevices,
      onConnect: _controller.connectToDevice,
      onDisconnect: () => _controller.disconnect(context),
      onStartScan: _controller.startScan,
      onStopScan: _controller.stopScan,
    );
  }
  
  Widget _buildTabBar() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(icon: Icon(Icons.map), text: 'Map'),
          Tab(icon: Icon(Icons.list), text: 'Phone GPS'),
          Tab(icon: Icon(Icons.history), text: 'Tracker GPS'),
        ],
      ),
    );
  }
  
  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        // Map View
        LocationTrackingView(
          locations: _controller.locationHistory,
          currentLocation: _controller.currentLocation,
          mcuGpsHistory: _controller.mcuGpsHistory,
          isTracking: _controller.isTrackingLocation,
          selectedLocation: _controller.selectedMapLocation,
          onLocationTap: _controller.selectMapLocation,
        ),
        
        // Phone GPS History List
        GpsHistoryView(
          title: 'Phone GPS History',
          locations: _controller.locationHistory,
          isPhone: true,
          onLocationTap: (location) {
            _controller.selectMapLocation(location.toLatLng());
            _tabController.animateTo(0); // Switch to map
          },
          onClear: _controller.clearPhoneHistory,
        ),
        
        // Tracker GPS History List
        GpsHistoryView(
          title: 'Tracker GPS History',
          mcuHistory: _controller.mcuGpsHistory,
          isPhone: false,
          onLocationTap: (location) {
            _controller.selectMapLocation(location.toLatLng());
            _tabController.animateTo(0); // Switch to map
          },
          onClear: _controller.clearTrackerHistory,
          onRefresh: _controller.fetchMcuGpsHistory,
        ),
      ],
    );
  }
  
  Widget? _buildFAB() {
    // Show FAB only on map tab for location tracking
    if (_tabController.index != 0) return null;
    
    return FloatingActionButton(
      onPressed: _controller.toggleLocationTracking,
      child: Icon(
        _controller.isTrackingLocation 
          ? Icons.location_off 
          : Icons.location_on,
      ),
    );
  }
  
  Future<void> _navigateToSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    
    if (result == true && mounted) {
      _controller.syncConfiguration();
    }
  }
}