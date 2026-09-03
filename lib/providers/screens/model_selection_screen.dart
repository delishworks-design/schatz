import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/models/provider_profile.dart';
import '../../providers/services/provider_service.dart';
import '../widgets/model_info_card.dart';

class ModelSelectionScreen extends StatefulWidget {
  const ModelSelectionScreen({super.key});
  
  @override
  State<ModelSelectionScreen> createState() => _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends State<ModelSelectionScreen> {
  final ProviderService _providerService = ProviderService();
  List<ProviderProfile> _providers = [];
  List<ProviderModel> _allModels = [];
  List<ProviderModel> _filteredModels = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedProviderFilter;
  
  @override
  void initState() {
    super.initState();
    _loadModels();
  }
  
  Future<void> _loadModels() async {
    setState(() => _isLoading = true);
    
    final profiles = await _providerService.getProfiles();
    if (!mounted) return;
    _providers = profiles;
    
    final allModels = <ProviderModel>[];
    for (final profile in profiles) {
      try {
        final models = await _providerService.listModels(profile);
        for (final model in models) {
          allModels.add(model);
        }
      } catch (_) {}
    }
    
    if (!mounted) return;
    setState(() {
      _allModels = allModels;
      _filteredModels = allModels;
      _isLoading = false;
    });
  }
  
  void _filterModels() {
    setState(() {
      _filteredModels = _allModels.where((model) {
        final matchesSearch = _searchQuery.isEmpty ||
            model.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            model.id.toLowerCase().contains(_searchQuery.toLowerCase());
        
        final matchesProvider = _selectedProviderFilter == null ||
            model.providerId == _selectedProviderFilter;
        
        return matchesSearch && matchesProvider;
      }).toList();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Select Model'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadModels,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildProviderFilter(),
          Expanded(
            child: _buildModelList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: (value) {
          _searchQuery = value;
          _filterModels();
        },
        decoration: InputDecoration(
          hintText: 'Search models...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchQuery = '';
                    _filterModels();
                  },
                )
              : null,
        ),
      ),
    );
  }
  
  Widget _buildProviderFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All', null),
          ..._providers.map((provider) => _buildFilterChip(provider.displayName, provider.id)),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String? providerId) {
    final isSelected = _selectedProviderFilter == providerId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedProviderFilter = providerId;
          });
          _filterModels();
        },
        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
        checkmarkColor: AppTheme.primaryColor,
      ),
    );
  }
  
  Widget _buildModelList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading models...', style: TextStyle(color: AppTheme.textSecondaryColor)),
          ],
        ),
      );
    }
    
    if (_filteredModels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: AppTheme.textSecondaryColor),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No models match your search' : 'No models available',
              style: const TextStyle(color: AppTheme.textSecondaryColor),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a provider and scan for models first',
              style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredModels.length,
      itemBuilder: (context, index) {
        final model = _filteredModels[index];
        return ModelInfoCard(
          model: model,
          onTap: () => _selectModel(model),
        );
      },
    );
  }
  
  void _selectModel(ProviderModel model) {
    Navigator.pop(context, model);
  }
}
