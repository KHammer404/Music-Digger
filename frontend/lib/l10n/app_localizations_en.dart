// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Music Digger';

  @override
  String get home => 'Home';

  @override
  String get search => 'Search';

  @override
  String get library => 'Library';

  @override
  String get settings => 'Settings';

  @override
  String get searchHint => 'Search artists, tracks...';

  @override
  String get noResults => 'No results found';

  @override
  String get playlists => 'Playlists';

  @override
  String get favorites => 'Favorites';

  @override
  String get history => 'History';

  @override
  String get noPlaylists => 'No playlists yet';

  @override
  String get noFavorites => 'No favorites yet';

  @override
  String get noHistory => 'No history yet';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get version => 'Version';

  @override
  String get platforms => 'Platforms';

  @override
  String get tracks => 'Tracks';

  @override
  String get artists => 'Artists';

  @override
  String get discover => 'Discover';

  @override
  String get discoverSubtitle => 'Artists you might like';

  @override
  String get similarArtists => 'Similar Artists';

  @override
  String get trending => 'Trending';

  @override
  String get digDeeper => 'Dig Deeper';

  @override
  String get digDeeperSubtitle =>
      'Find hidden tracks across YouTube, Spotify, NicoNico, and 5 more platforms';

  @override
  String get searchArtists => 'Search Artists';

  @override
  String get startSearching => 'Start Searching';

  @override
  String get retry => 'Retry';

  @override
  String get couldNotLoad => 'Could not load recommendations';

  @override
  String get newPlaylist => 'New Playlist';

  @override
  String get playlistName => 'Playlist name';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get delete => 'Delete';

  @override
  String get importPlaylist => 'Import Playlist';

  @override
  String get exportJson => 'Export JSON';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get exportM3u => 'Export M3U';

  @override
  String get pasteJsonTracks => 'Paste JSON tracks';

  @override
  String get import_ => 'Import';

  @override
  String get goBack => 'Go Back';

  @override
  String get failedToLoadArtist => 'Failed to load artist';

  @override
  String get tapMenuToCreateOrImport => 'Tap menu to create or import';

  @override
  String get networkError => 'Network error. Please check your connection.';

  @override
  String get timeout => 'Request timed out. Please try again.';

  @override
  String get unknownError => 'Something went wrong. Please try again.';

  @override
  String get loading => 'Loading...';

  @override
  String nTracksCount(int count) {
    return '$count tracks';
  }

  @override
  String similarTo(String name) {
    return 'Similar to $name';
  }

  @override
  String exportedAs(String name, String format) {
    return '$name exported as $format';
  }

  @override
  String importedTracks(int count, String name) {
    return 'Imported $count tracks to \"$name\"';
  }

  @override
  String get offline => 'You are offline';

  @override
  String get retryAction => 'Retry';

  @override
  String get checkConnection =>
      'Please check your internet connection and try again';

  @override
  String get serverSlow => 'Server is responding slowly';

  @override
  String get tryAgainLater => 'Please try again later';

  @override
  String get serverError => 'Server is experiencing issues';

  @override
  String get notFound => 'Requested item not found';

  @override
  String get dataError => 'Error processing data';

  @override
  String get unknownErrorOccurred => 'An unknown error occurred';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get basedOnRecent => 'Based on your recent activity';

  @override
  String get searchForArtistsOrTracks => 'Search for artists or tracks';

  @override
  String get trySearchExample => 'Try \"ななひら\", \"Nanahira\", or \"나나히라\"';

  @override
  String get discoverMusicAcross => 'Discover music across 8 platforms';

  @override
  String get findHiddenTracks =>
      'Find hidden tracks across YouTube, Spotify, NicoNico, and 5 more platforms';
}
