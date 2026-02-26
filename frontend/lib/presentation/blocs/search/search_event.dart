import 'package:equatable/equatable.dart';

sealed class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class SearchQueryChanged extends SearchEvent {
  final String query;
  const SearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class SearchSubmitted extends SearchEvent {
  final String query;
  final List<String>? platforms;
  const SearchSubmitted(this.query, {this.platforms});

  @override
  List<Object?> get props => [query, platforms];
}

class SearchPlatformToggled extends SearchEvent {
  final String platform;
  const SearchPlatformToggled(this.platform);

  @override
  List<Object?> get props => [platform];
}

class SearchCleared extends SearchEvent {
  const SearchCleared();
}

class SearchLoadMore extends SearchEvent {
  const SearchLoadMore();
}
