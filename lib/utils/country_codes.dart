import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:developer' as developer;

class CountryCode {
  final String code;
  final String country;
  final String name;
  final String flag;

  const CountryCode({
    required this.code,
    required this.country,
    required this.name,
    required this.flag,
  });
}

class CountryCodeHelper {
  // Comprehensive list of country codes sorted alphabetically by country name
  static final List<CountryCode> countryCodes = [
    CountryCode(code: '+93', country: 'AF', name: 'Afghanistan', flag: '🇦🇫'),
    CountryCode(code: '+355', country: 'AL', name: 'Albania', flag: '🇦🇱'),
    CountryCode(code: '+213', country: 'DZ', name: 'Algeria', flag: '🇩🇿'),
    CountryCode(code: '+54', country: 'AR', name: 'Argentina', flag: '🇦🇷'),
    CountryCode(code: '+374', country: 'AM', name: 'Armenia', flag: '🇦🇲'),
    CountryCode(code: '+61', country: 'AU', name: 'Australia', flag: '🇦🇺'),
    CountryCode(code: '+43', country: 'AT', name: 'Austria', flag: '🇦🇹'),
    CountryCode(code: '+994', country: 'AZ', name: 'Azerbaijan', flag: '🇦🇿'),
    CountryCode(code: '+973', country: 'BH', name: 'Bahrain', flag: '🇧🇭'),
    CountryCode(code: '+880', country: 'BD', name: 'Bangladesh', flag: '🇧🇩'),
    CountryCode(code: '+375', country: 'BY', name: 'Belarus', flag: '🇧🇾'),
    CountryCode(code: '+32', country: 'BE', name: 'Belgium', flag: '🇧🇪'),
    CountryCode(code: '+591', country: 'BO', name: 'Bolivia', flag: '🇧🇴'),
    CountryCode(code: '+387', country: 'BA', name: 'Bosnia', flag: '🇧🇦'),
    CountryCode(code: '+55', country: 'BR', name: 'Brazil', flag: '🇧🇷'),
    CountryCode(code: '+673', country: 'BN', name: 'Brunei', flag: '🇧🇳'),
    CountryCode(code: '+359', country: 'BG', name: 'Bulgaria', flag: '🇧🇬'),
    CountryCode(code: '+855', country: 'KH', name: 'Cambodia', flag: '🇰🇭'),
    CountryCode(code: '+237', country: 'CM', name: 'Cameroon', flag: '🇨🇲'),
    CountryCode(code: '+1', country: 'CA', name: 'Canada', flag: '🇨🇦'),
    CountryCode(code: '+56', country: 'CL', name: 'Chile', flag: '🇨🇱'),
    CountryCode(code: '+86', country: 'CN', name: 'China', flag: '🇨🇳'),
    CountryCode(code: '+57', country: 'CO', name: 'Colombia', flag: '🇨🇴'),
    CountryCode(code: '+506', country: 'CR', name: 'Costa Rica', flag: '🇨🇷'),
    CountryCode(code: '+385', country: 'HR', name: 'Croatia', flag: '🇭🇷'),
    CountryCode(code: '+53', country: 'CU', name: 'Cuba', flag: '🇨🇺'),
    CountryCode(code: '+357', country: 'CY', name: 'Cyprus', flag: '🇨🇾'),
    CountryCode(code: '+420', country: 'CZ', name: 'Czech Republic', flag: '🇨🇿'),
    CountryCode(code: '+45', country: 'DK', name: 'Denmark', flag: '🇩🇰'),
    CountryCode(code: '+593', country: 'EC', name: 'Ecuador', flag: '🇪🇨'),
    CountryCode(code: '+20', country: 'EG', name: 'Egypt', flag: '🇪🇬'),
    CountryCode(code: '+503', country: 'SV', name: 'El Salvador', flag: '🇸🇻'),
    CountryCode(code: '+372', country: 'EE', name: 'Estonia', flag: '🇪🇪'),
    CountryCode(code: '+251', country: 'ET', name: 'Ethiopia', flag: '🇪🇹'),
    CountryCode(code: '+358', country: 'FI', name: 'Finland', flag: '🇫🇮'),
    CountryCode(code: '+33', country: 'FR', name: 'France', flag: '🇫🇷'),
    CountryCode(code: '+995', country: 'GE', name: 'Georgia', flag: '🇬🇪'),
    CountryCode(code: '+49', country: 'DE', name: 'Germany', flag: '🇩🇪'),
    CountryCode(code: '+233', country: 'GH', name: 'Ghana', flag: '🇬🇭'),
    CountryCode(code: '+30', country: 'GR', name: 'Greece', flag: '🇬🇷'),
    CountryCode(code: '+502', country: 'GT', name: 'Guatemala', flag: '🇬🇹'),
    CountryCode(code: '+504', country: 'HN', name: 'Honduras', flag: '🇭🇳'),
    CountryCode(code: '+852', country: 'HK', name: 'Hong Kong', flag: '🇭🇰'),
    CountryCode(code: '+36', country: 'HU', name: 'Hungary', flag: '🇭🇺'),
    CountryCode(code: '+354', country: 'IS', name: 'Iceland', flag: '🇮🇸'),
    CountryCode(code: '+91', country: 'IN', name: 'India', flag: '🇮🇳'),
    CountryCode(code: '+62', country: 'ID', name: 'Indonesia', flag: '🇮🇩'),
    CountryCode(code: '+98', country: 'IR', name: 'Iran', flag: '🇮🇷'),
    CountryCode(code: '+964', country: 'IQ', name: 'Iraq', flag: '🇮🇶'),
    CountryCode(code: '+353', country: 'IE', name: 'Ireland', flag: '🇮🇪'),
    CountryCode(code: '+972', country: 'IL', name: 'Israel', flag: '🇮🇱'),
    CountryCode(code: '+39', country: 'IT', name: 'Italy', flag: '🇮🇹'),
    CountryCode(code: '+81', country: 'JP', name: 'Japan', flag: '🇯🇵'),
    CountryCode(code: '+962', country: 'JO', name: 'Jordan', flag: '🇯🇴'),
    CountryCode(code: '+7', country: 'KZ', name: 'Kazakhstan', flag: '🇰🇿'),
    CountryCode(code: '+254', country: 'KE', name: 'Kenya', flag: '🇰🇪'),
    CountryCode(code: '+965', country: 'KW', name: 'Kuwait', flag: '🇰🇼'),
    CountryCode(code: '+996', country: 'KG', name: 'Kyrgyzstan', flag: '🇰🇬'),
    CountryCode(code: '+856', country: 'LA', name: 'Laos', flag: '🇱🇦'),
    CountryCode(code: '+371', country: 'LV', name: 'Latvia', flag: '🇱🇻'),
    CountryCode(code: '+961', country: 'LB', name: 'Lebanon', flag: '🇱🇧'),
    CountryCode(code: '+218', country: 'LY', name: 'Libya', flag: '🇱🇾'),
    CountryCode(code: '+370', country: 'LT', name: 'Lithuania', flag: '🇱🇹'),
    CountryCode(code: '+352', country: 'LU', name: 'Luxembourg', flag: '🇱🇺'),
    CountryCode(code: '+853', country: 'MO', name: 'Macau', flag: '🇲🇴'),
    CountryCode(code: '+389', country: 'MK', name: 'Macedonia', flag: '🇲🇰'),
    CountryCode(code: '+60', country: 'MY', name: 'Malaysia', flag: '🇲🇾'),
    CountryCode(code: '+356', country: 'MT', name: 'Malta', flag: '🇲🇹'),
    CountryCode(code: '+52', country: 'MX', name: 'Mexico', flag: '🇲🇽'),
    CountryCode(code: '+373', country: 'MD', name: 'Moldova', flag: '🇲🇩'),
    CountryCode(code: '+377', country: 'MC', name: 'Monaco', flag: '🇲🇨'),
    CountryCode(code: '+976', country: 'MN', name: 'Mongolia', flag: '🇲🇳'),
    CountryCode(code: '+382', country: 'ME', name: 'Montenegro', flag: '🇲🇪'),
    CountryCode(code: '+212', country: 'MA', name: 'Morocco', flag: '🇲🇦'),
    CountryCode(code: '+95', country: 'MM', name: 'Myanmar', flag: '🇲🇲'),
    CountryCode(code: '+977', country: 'NP', name: 'Nepal', flag: '🇳🇵'),
    CountryCode(code: '+31', country: 'NL', name: 'Netherlands', flag: '🇳🇱'),
    CountryCode(code: '+64', country: 'NZ', name: 'New Zealand', flag: '🇳🇿'),
    CountryCode(code: '+505', country: 'NI', name: 'Nicaragua', flag: '🇳🇮'),
    CountryCode(code: '+234', country: 'NG', name: 'Nigeria', flag: '🇳🇬'),
    CountryCode(code: '+47', country: 'NO', name: 'Norway', flag: '🇳🇴'),
    CountryCode(code: '+968', country: 'OM', name: 'Oman', flag: '🇴🇲'),
    CountryCode(code: '+92', country: 'PK', name: 'Pakistan', flag: '🇵🇰'),
    CountryCode(code: '+507', country: 'PA', name: 'Panama', flag: '🇵🇦'),
    CountryCode(code: '+595', country: 'PY', name: 'Paraguay', flag: '🇵🇾'),
    CountryCode(code: '+51', country: 'PE', name: 'Peru', flag: '🇵🇪'),
    CountryCode(code: '+63', country: 'PH', name: 'Philippines', flag: '🇵🇭'),
    CountryCode(code: '+48', country: 'PL', name: 'Poland', flag: '🇵🇱'),
    CountryCode(code: '+351', country: 'PT', name: 'Portugal', flag: '🇵🇹'),
    CountryCode(code: '+974', country: 'QA', name: 'Qatar', flag: '🇶🇦'),
    CountryCode(code: '+40', country: 'RO', name: 'Romania', flag: '🇷🇴'),
    CountryCode(code: '+7', country: 'RU', name: 'Russia', flag: '🇷🇺'),
    CountryCode(code: '+250', country: 'RW', name: 'Rwanda', flag: '🇷🇼'),
    CountryCode(code: '+966', country: 'SA', name: 'Saudi Arabia', flag: '🇸🇦'),
    CountryCode(code: '+381', country: 'RS', name: 'Serbia', flag: '🇷🇸'),
    CountryCode(code: '+65', country: 'SG', name: 'Singapore', flag: '🇸🇬'),
    CountryCode(code: '+421', country: 'SK', name: 'Slovakia', flag: '🇸🇰'),
    CountryCode(code: '+386', country: 'SI', name: 'Slovenia', flag: '🇸🇮'),
    CountryCode(code: '+27', country: 'ZA', name: 'South Africa', flag: '🇿🇦'),
    CountryCode(code: '+82', country: 'KR', name: 'South Korea', flag: '🇰🇷'),
    CountryCode(code: '+34', country: 'ES', name: 'Spain', flag: '🇪🇸'),
    CountryCode(code: '+94', country: 'LK', name: 'Sri Lanka', flag: '🇱🇰'),
    CountryCode(code: '+249', country: 'SD', name: 'Sudan', flag: '🇸🇩'),
    CountryCode(code: '+46', country: 'SE', name: 'Sweden', flag: '🇸🇪'),
    CountryCode(code: '+41', country: 'CH', name: 'Switzerland', flag: '🇨🇭'),
    CountryCode(code: '+963', country: 'SY', name: 'Syria', flag: '🇸🇾'),
    CountryCode(code: '+886', country: 'TW', name: 'Taiwan', flag: '🇹🇼'),
    CountryCode(code: '+992', country: 'TJ', name: 'Tajikistan', flag: '🇹🇯'),
    CountryCode(code: '+255', country: 'TZ', name: 'Tanzania', flag: '🇹🇿'),
    CountryCode(code: '+66', country: 'TH', name: 'Thailand', flag: '🇹🇭'),
    CountryCode(code: '+216', country: 'TN', name: 'Tunisia', flag: '🇹🇳'),
    CountryCode(code: '+90', country: 'TR', name: 'Turkey', flag: '🇹🇷'),
    CountryCode(code: '+993', country: 'TM', name: 'Turkmenistan', flag: '🇹🇲'),
    CountryCode(code: '+256', country: 'UG', name: 'Uganda', flag: '🇺🇬'),
    CountryCode(code: '+380', country: 'UA', name: 'Ukraine', flag: '🇺🇦'),
    CountryCode(code: '+971', country: 'AE', name: 'United Arab Emirates', flag: '🇦🇪'),
    CountryCode(code: '+44', country: 'GB', name: 'United Kingdom', flag: '🇬🇧'),
    CountryCode(code: '+1', country: 'US', name: 'United States', flag: '🇺🇸'),
    CountryCode(code: '+598', country: 'UY', name: 'Uruguay', flag: '🇺🇾'),
    CountryCode(code: '+998', country: 'UZ', name: 'Uzbekistan', flag: '🇺🇿'),
    CountryCode(code: '+58', country: 'VE', name: 'Venezuela', flag: '🇻🇪'),
    CountryCode(code: '+84', country: 'VN', name: 'Vietnam', flag: '🇻🇳'),
    CountryCode(code: '+967', country: 'YE', name: 'Yemen', flag: '🇾🇪'),
    CountryCode(code: '+260', country: 'ZM', name: 'Zambia', flag: '🇿🇲'),
    CountryCode(code: '+263', country: 'ZW', name: 'Zimbabwe', flag: '🇿🇼'),
  ];

  // Get country code based on current location
  static Future<String?> getCountryCodeByLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        developer.log('Location services are disabled', name: 'CountryCode');
        return null;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          developer.log('Location permissions are denied', name: 'CountryCode');
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        developer.log('Location permissions are permanently denied', name: 'CountryCode');
        return null;
      }

      // Get current position with new locationSettings API
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Get country from coordinates using geocoding
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        String? countryCode = placemarks.first.isoCountryCode;
        developer.log('Detected country code: $countryCode', name: 'CountryCode');
        
        if (countryCode != null) {
          // Find matching country code
          CountryCode? country = countryCodes.firstWhere(
            (c) => c.country == countryCode,
            orElse: () => countryCodes.firstWhere((c) => c.country == 'US'),
          );
          return country.code;
        }
      }
    } catch (e) {
      developer.log('Error getting country by location: $e', name: 'CountryCode', error: e);
    }
    
    // Default to US if detection fails
    return '+1';
  }

  // Get CountryCode object by dial code
  static CountryCode? getCountryByDialCode(String dialCode) {
    try {
      return countryCodes.firstWhere((c) => c.code == dialCode);
    } catch (e) {
      return null;
    }
  }

  // Search countries by name or code
  static List<CountryCode> searchCountries(String query) {
    if (query.isEmpty) return countryCodes;
    
    String lowerQuery = query.toLowerCase();
    return countryCodes.where((country) {
      return country.name.toLowerCase().contains(lowerQuery) ||
             country.code.contains(query) ||
             country.country.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}