// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '뮤직 디거';

  @override
  String get home => '홈';

  @override
  String get search => '검색';

  @override
  String get library => '라이브러리';

  @override
  String get settings => '설정';

  @override
  String get searchHint => '아티스트, 트랙 검색...';

  @override
  String get noResults => '결과 없음';

  @override
  String get playlists => '플레이리스트';

  @override
  String get favorites => '즐겨찾기';

  @override
  String get history => '히스토리';

  @override
  String get noPlaylists => '플레이리스트가 없습니다';

  @override
  String get noFavorites => '즐겨찾기가 없습니다';

  @override
  String get noHistory => '히스토리가 없습니다';

  @override
  String get language => '언어';

  @override
  String get theme => '테마';

  @override
  String get version => '버전';

  @override
  String get platforms => '플랫폼';

  @override
  String get tracks => '트랙';

  @override
  String get artists => '아티스트';

  @override
  String get discover => '디스커버';

  @override
  String get discoverSubtitle => '좋아할 만한 아티스트';

  @override
  String get similarArtists => '비슷한 아티스트';

  @override
  String get trending => '트렌딩';

  @override
  String get digDeeper => '더 깊이 파기';

  @override
  String get digDeeperSubtitle =>
      'YouTube, Spotify, NicoNico 등 8개 플랫폼에서 숨겨진 트랙을 찾아보세요';

  @override
  String get searchArtists => '아티스트 검색';

  @override
  String get startSearching => '검색 시작';

  @override
  String get retry => '재시도';

  @override
  String get couldNotLoad => '추천을 불러올 수 없습니다';

  @override
  String get newPlaylist => '새 플레이리스트';

  @override
  String get playlistName => '플레이리스트 이름';

  @override
  String get cancel => '취소';

  @override
  String get create => '만들기';

  @override
  String get delete => '삭제';

  @override
  String get importPlaylist => '플레이리스트 가져오기';

  @override
  String get exportJson => 'JSON 내보내기';

  @override
  String get exportCsv => 'CSV 내보내기';

  @override
  String get exportM3u => 'M3U 내보내기';

  @override
  String get pasteJsonTracks => 'JSON 트랙 붙여넣기';

  @override
  String get import_ => '가져오기';

  @override
  String get goBack => '뒤로';

  @override
  String get failedToLoadArtist => '아티스트를 불러오지 못했습니다';

  @override
  String get tapMenuToCreateOrImport => '메뉴에서 만들기 또는 가져오기';

  @override
  String get networkError => '네트워크 오류. 연결을 확인해주세요.';

  @override
  String get timeout => '요청 시간 초과. 다시 시도해주세요.';

  @override
  String get unknownError => '문제가 발생했습니다. 다시 시도해주세요.';

  @override
  String get loading => '로딩 중...';

  @override
  String nTracksCount(int count) {
    return '$count곡';
  }

  @override
  String similarTo(String name) {
    return '$name과(와) 비슷한 아티스트';
  }

  @override
  String exportedAs(String name, String format) {
    return '$name을(를) $format으로 내보냈습니다';
  }

  @override
  String importedTracks(int count, String name) {
    return '\"$name\"에 $count곡을 가져왔습니다';
  }

  @override
  String get offline => '오프라인 상태입니다';

  @override
  String get retryAction => '다시 시도';

  @override
  String get checkConnection => '인터넷 연결을 확인하고 다시 시도해주세요';

  @override
  String get serverSlow => '서버 응답이 느립니다';

  @override
  String get tryAgainLater => '잠시 후 다시 시도해주세요';

  @override
  String get serverError => '서버에 일시적인 문제가 있습니다';

  @override
  String get notFound => '요청한 항목을 찾을 수 없습니다';

  @override
  String get dataError => '데이터를 처리하는 중 오류가 발생했습니다';

  @override
  String get unknownErrorOccurred => '알 수 없는 오류가 발생했습니다';

  @override
  String get errorOccurred => '오류가 발생했습니다';

  @override
  String get basedOnRecent => '최근 활동 기반';

  @override
  String get searchForArtistsOrTracks => '아티스트 또는 트랙을 검색하세요';

  @override
  String get trySearchExample => '\"ななひら\", \"Nanahira\", \"나나히라\" 검색해보세요';

  @override
  String get discoverMusicAcross => '8개 플랫폼에서 음악 탐색';

  @override
  String get findHiddenTracks =>
      'YouTube, Spotify, NicoNico 등 8개 플랫폼에서 숨겨진 트랙을 찾아보세요';
}
