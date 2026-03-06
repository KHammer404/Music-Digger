// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'ミュージックディガー';

  @override
  String get home => 'ホーム';

  @override
  String get search => '検索';

  @override
  String get library => 'ライブラリ';

  @override
  String get settings => '設定';

  @override
  String get searchHint => 'アーティスト、トラックを検索...';

  @override
  String get noResults => '結果なし';

  @override
  String get playlists => 'プレイリスト';

  @override
  String get favorites => 'お気に入り';

  @override
  String get history => '履歴';

  @override
  String get noPlaylists => 'プレイリストはまだありません';

  @override
  String get noFavorites => 'お気に入りはまだありません';

  @override
  String get noHistory => '履歴はまだありません';

  @override
  String get language => '言語';

  @override
  String get theme => 'テーマ';

  @override
  String get version => 'バージョン';

  @override
  String get platforms => 'プラットフォーム';

  @override
  String get tracks => 'トラック';

  @override
  String get artists => 'アーティスト';

  @override
  String get discover => 'ディスカバー';

  @override
  String get discoverSubtitle => 'おすすめのアーティスト';

  @override
  String get similarArtists => '似ているアーティスト';

  @override
  String get trending => 'トレンド';

  @override
  String get digDeeper => 'もっと深く掘る';

  @override
  String get digDeeperSubtitle =>
      'YouTube、Spotify、ニコニコなど8つのプラットフォームから隠れたトラックを発見';

  @override
  String get searchArtists => 'アーティストを検索';

  @override
  String get startSearching => '検索を始める';

  @override
  String get retry => '再試行';

  @override
  String get couldNotLoad => 'おすすめを読み込めませんでした';

  @override
  String get newPlaylist => '新規プレイリスト';

  @override
  String get playlistName => 'プレイリスト名';

  @override
  String get cancel => 'キャンセル';

  @override
  String get create => '作成';

  @override
  String get delete => '削除';

  @override
  String get importPlaylist => 'プレイリストをインポート';

  @override
  String get exportJson => 'JSONエクスポート';

  @override
  String get exportCsv => 'CSVエクスポート';

  @override
  String get exportM3u => 'M3Uエクスポート';

  @override
  String get pasteJsonTracks => 'JSONトラックを貼り付け';

  @override
  String get import_ => 'インポート';

  @override
  String get goBack => '戻る';

  @override
  String get failedToLoadArtist => 'アーティストの読み込みに失敗しました';

  @override
  String get tapMenuToCreateOrImport => 'メニューから作成またはインポート';

  @override
  String get networkError => 'ネットワークエラー。接続を確認してください。';

  @override
  String get timeout => 'リクエストがタイムアウトしました。再試行してください。';

  @override
  String get unknownError => '問題が発生しました。再試行してください。';

  @override
  String get loading => '読み込み中...';

  @override
  String nTracksCount(int count) {
    return '$count曲';
  }

  @override
  String similarTo(String name) {
    return '$nameに似たアーティスト';
  }

  @override
  String exportedAs(String name, String format) {
    return '$nameを$formatでエクスポートしました';
  }

  @override
  String importedTracks(int count, String name) {
    return '「$name」に$count曲をインポートしました';
  }

  @override
  String get offline => 'オフラインです';

  @override
  String get retryAction => '再試行';

  @override
  String get checkConnection => 'インターネット接続を確認して再試行してください';

  @override
  String get serverSlow => 'サーバーの応答が遅いです';

  @override
  String get tryAgainLater => 'しばらくしてから再試行してください';

  @override
  String get serverError => 'サーバーに一時的な問題があります';

  @override
  String get notFound => 'リクエストされた項目が見つかりません';

  @override
  String get dataError => 'データの処理中にエラーが発生しました';

  @override
  String get unknownErrorOccurred => '不明なエラーが発生しました';

  @override
  String get errorOccurred => 'エラーが発生しました';

  @override
  String get basedOnRecent => '最近のアクティビティに基づく';

  @override
  String get searchForArtistsOrTracks => 'アーティストまたはトラックを検索';

  @override
  String get trySearchExample => '\"ななひら\"、\"Nanahira\"、\"나나히라\"で検索してみてください';

  @override
  String get discoverMusicAcross => '8つのプラットフォームで音楽を探索';

  @override
  String get findHiddenTracks =>
      'YouTube、Spotify、ニコニコなど8つのプラットフォームから隠れたトラックを発見';
}
