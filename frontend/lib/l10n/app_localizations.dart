import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Music Digger'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search artists, tracks...'**
  String get searchHint;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @noPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get noPlaylists;

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavorites;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get noHistory;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @platforms.
  ///
  /// In en, this message translates to:
  /// **'Platforms'**
  String get platforms;

  /// No description provided for @tracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get tracks;

  /// No description provided for @artists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get artists;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @discoverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Artists you might like'**
  String get discoverSubtitle;

  /// No description provided for @similarArtists.
  ///
  /// In en, this message translates to:
  /// **'Similar Artists'**
  String get similarArtists;

  /// No description provided for @trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// No description provided for @digDeeper.
  ///
  /// In en, this message translates to:
  /// **'Dig Deeper'**
  String get digDeeper;

  /// No description provided for @digDeeperSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find hidden tracks across YouTube, Spotify, NicoNico, and 5 more platforms'**
  String get digDeeperSubtitle;

  /// No description provided for @searchArtists.
  ///
  /// In en, this message translates to:
  /// **'Search Artists'**
  String get searchArtists;

  /// No description provided for @startSearching.
  ///
  /// In en, this message translates to:
  /// **'Start Searching'**
  String get startSearching;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @couldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load recommendations'**
  String get couldNotLoad;

  /// No description provided for @newPlaylist.
  ///
  /// In en, this message translates to:
  /// **'New Playlist'**
  String get newPlaylist;

  /// No description provided for @playlistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get playlistName;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @importPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Import Playlist'**
  String get importPlaylist;

  /// No description provided for @exportJson.
  ///
  /// In en, this message translates to:
  /// **'Export JSON'**
  String get exportJson;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @exportM3u.
  ///
  /// In en, this message translates to:
  /// **'Export M3U'**
  String get exportM3u;

  /// No description provided for @pasteJsonTracks.
  ///
  /// In en, this message translates to:
  /// **'Paste JSON tracks'**
  String get pasteJsonTracks;

  /// No description provided for @import_.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import_;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @failedToLoadArtist.
  ///
  /// In en, this message translates to:
  /// **'Failed to load artist'**
  String get failedToLoadArtist;

  /// No description provided for @tapMenuToCreateOrImport.
  ///
  /// In en, this message translates to:
  /// **'Tap menu to create or import'**
  String get tapMenuToCreateOrImport;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get networkError;

  /// No description provided for @timeout.
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Please try again.'**
  String get timeout;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get unknownError;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @nTracksCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tracks'**
  String nTracksCount(int count);

  /// No description provided for @similarTo.
  ///
  /// In en, this message translates to:
  /// **'Similar to {name}'**
  String similarTo(String name);

  /// No description provided for @exportedAs.
  ///
  /// In en, this message translates to:
  /// **'{name} exported as {format}'**
  String exportedAs(String name, String format);

  /// No description provided for @importedTracks.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} tracks to \"{name}\"'**
  String importedTracks(int count, String name);

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get offline;

  /// No description provided for @retryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryAction;

  /// No description provided for @checkConnection.
  ///
  /// In en, this message translates to:
  /// **'Please check your internet connection and try again'**
  String get checkConnection;

  /// No description provided for @serverSlow.
  ///
  /// In en, this message translates to:
  /// **'Server is responding slowly'**
  String get serverSlow;

  /// No description provided for @tryAgainLater.
  ///
  /// In en, this message translates to:
  /// **'Please try again later'**
  String get tryAgainLater;

  /// No description provided for @serverError.
  ///
  /// In en, this message translates to:
  /// **'Server is experiencing issues'**
  String get serverError;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Requested item not found'**
  String get notFound;

  /// No description provided for @dataError.
  ///
  /// In en, this message translates to:
  /// **'Error processing data'**
  String get dataError;

  /// No description provided for @unknownErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred'**
  String get unknownErrorOccurred;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// No description provided for @basedOnRecent.
  ///
  /// In en, this message translates to:
  /// **'Based on your recent activity'**
  String get basedOnRecent;

  /// No description provided for @searchForArtistsOrTracks.
  ///
  /// In en, this message translates to:
  /// **'Search for artists or tracks'**
  String get searchForArtistsOrTracks;

  /// No description provided for @trySearchExample.
  ///
  /// In en, this message translates to:
  /// **'Try \"ななひら\", \"Nanahira\", or \"나나히라\"'**
  String get trySearchExample;

  /// No description provided for @discoverMusicAcross.
  ///
  /// In en, this message translates to:
  /// **'Discover music across 8 platforms'**
  String get discoverMusicAcross;

  /// No description provided for @findHiddenTracks.
  ///
  /// In en, this message translates to:
  /// **'Find hidden tracks across YouTube, Spotify, NicoNico, and 5 more platforms'**
  String get findHiddenTracks;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
