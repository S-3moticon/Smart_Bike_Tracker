import 'package:flutter/material.dart';
import '../utils/country_codes.dart';

class CountryPickerDialog extends StatefulWidget {
  final String selectedCode;
  final Function(CountryCode) onCountrySelected;
  final ScrollController scrollController;

  const CountryPickerDialog({
    super.key,
    required this.selectedCode,
    required this.onCountrySelected,
    required this.scrollController,
  });

  @override
  State<CountryPickerDialog> createState() => _CountryPickerDialogState();
}

class _CountryPickerDialogState extends State<CountryPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<CountryCode> _filteredCountries = CountryCodeHelper.countryCodes;
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterCountries);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  void _filterCountries() {
    setState(() {
      _filteredCountries = CountryCodeHelper.searchCountries(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Select Country Code',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search country...',
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
                        onPressed: () {
                          _searchController.clear();
                          _filterCountries();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Country list
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              itemCount: _filteredCountries.length,
              itemBuilder: (context, index) {
                final country = _filteredCountries[index];
                final isSelected = country.code == widget.selectedCode;
                
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Text(
                      country.flag,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      country.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      '${country.code} (${country.country})',
                      style: TextStyle(
                        color: isSelected 
                          ? colorScheme.primary.withValues(alpha: 0.8)
                          : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: colorScheme.primary,
                          )
                        : null,
                    onTap: () => widget.onCountrySelected(country),
                    dense: true,
                    tileColor: isSelected 
                      ? colorScheme.primaryContainer.withValues(alpha: 0.1)
                      : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}