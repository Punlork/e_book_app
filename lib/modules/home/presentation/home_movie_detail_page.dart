import 'dart:developer';

import 'package:e_book_app/index.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class HomeDetailPage extends StatefulWidget {
  const HomeDetailPage({super.key, required this.movieId});

  static const String routeName = 'home_detail_page';
  static const String routePath = '/home_detail_page';

  final String movieId;

  static final route = GoRoute(
    path: routePath,
    name: routeName,
    builder: (context, state) => HomeDetailPage(
      movieId: state.queryParams['movie_id'] ?? '',
    ),
    pageBuilder: (context, state) => AppRouteTransition(
      context: context,
      state: state,
      child: HomeDetailPage(
        movieId: state.queryParams['movie_id'] ?? '',
      ),
    ),
  );

  @override
  State<HomeDetailPage> createState() => _HomeDetailPageState();
}

class _HomeDetailPageState extends State<HomeDetailPage> {
  int movieIndex = 2;
  String _title = '';
  String videoId = '';
  PaginateStatus _status = PaginateStatus.initial;
  late ScrollController _scrollController;
  late YoutubePlayerController _youtubePlayerController;
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _youtubePlayerController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        forceHD: true,
      ),
    );
    _scrollController.addListener(_scrollListener);
    _onInit();
  }

  @override
  void didChangeDependencies() {
    BlocProvider.of<MovieSuggestionBloc>(context).add(
      OnGetMovieSuggestionClear(),
    );
    super.didChangeDependencies();
  }

  void _scrollListener() {
    final offset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;

    if (offset > 100) {
      _showTitle = true;
      setState(() {});
    } else {
      _showTitle = false;
      setState(() {});
    }

    if (offset == maxExtent && _status != PaginateStatus.empty) {
      BlocProvider.of<MovieSuggestionBloc>(context).add(
        OnGetMovieSuggestionNext(
          movieId: int.parse(widget.movieId),
          pageNumber: movieIndex,
        ),
      );
      movieIndex += 1;
    }
  }

  void _onInit() {
    BlocProvider.of<MovieDetailBloc>(context).add(
      OnGetMovieDetail(int.parse(widget.movieId)),
    );
    BlocProvider.of<MovieSuggestionBloc>(context).add(
      OnGetMovieSuggestion(int.parse(widget.movieId)),
    );

    BlocProvider.of<MovieReviewsBloc>(context).add(
      OnGetMovieReviews(
        movieId: int.parse(widget.movieId),
        pageNumber: 1,
      ),
    );
  }

  String _getTimeString(int value) {
    final hour = value ~/ 60;
    final minutes = value % 60;
    return '${hour.toString().padLeft(1, "0")}h:${minutes.toString().padLeft(2, "0")}m';
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<MovieSuggestionBloc, MovieSuggestionState>(
          listener: (context, state) {
            if (state is MovieSuggestionLoaded) {
              _status = state.status;
            }
          },
        ),
        BlocListener<MovieDetailBloc, MovieDetailState>(
          listener: (context, state) {
            if (state is MovieDetailLoaded) {
              if (state.movieDetail.isEmpty) {
                GoRouter.of(context).goNamed(
                  MainPage.routeName,
                );
              } else {
                _title = state.movieDetail.last.title;
                BlocProvider.of<GetVideoInfoBloc>(context).add(
                  OnGetVideoInfo(state.movieDetail.last.id),
                );
              }
            }
          },
        ),
        BlocListener<GetVideoInfoBloc, GetVideoInfoState>(
          listener: (context, state) {
            if (state is GetVideoInfoLoaded) {
              final videoOfficialId = state.videoInfo
                  .where((element) => element.official == true && element.type == 'Trailer')
                  .toList();
              videoId = videoOfficialId.first.key;
              setState(() {});
            }
          },
        ),
      ],
      child: YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _youtubePlayerController,
          showVideoProgressIndicator: true,
          onReady: () {
            _youtubePlayerController.load(videoId);
          },
        ),
        onExitFullScreen: SystemChrome.restoreSystemUIOverlays,
        builder: (_, player) => WillPopScope(
          onWillPop: () async {
            BlocListener<MovieDetailBloc, MovieDetailState>(
              listener: (context, state) {
                if (state is MovieDetailLoaded) {
                  if (state.movieDetail.isEmpty) {
                    GoRouter.of(context).goNamed(
                      MainPage.routeName,
                    );
                  } else {
                    _title = state.movieDetail.last.title;
                    BlocProvider.of<GetVideoInfoBloc>(context).add(
                      OnGetVideoInfo(state.movieDetail.last.id),
                    );
                  }
                }
              },
            );
            return true;
          },
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              titleSpacing: 0,
              title: Row(
                children: [
                  BlocSelector<MovieDetailBloc, MovieDetailState, MovieDetailLoaded?>(
                    selector: (state) {
                      if (state is MovieDetailLoaded) {
                        return state;
                      }
                      return null;
                    },
                    builder: (context, state) {
                      return CustomIconWidget(
                        icon: Icons.arrow_back,
                        onPressed: () {
                          if (state != null) {
                            GoRouter.of(context).pop();
                            BlocProvider.of<MovieDetailBloc>(context).add(
                              const OnRemoveMovieDetail(),
                            );
                          }
                        },
                      );
                    },
                  ),
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: _showTitle ? 1 : 0,
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        _title,
                        style: Theme.of(context).textTheme.headlineLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      CustomIconWidget(
                        icon: Icons.favorite_border,
                        onPressed: () {},
                      ),
                      CustomIconWidget(
                        icon: Icons.ios_share,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            body: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: <Widget>[
                  BlocBuilder<GetVideoInfoBloc, GetVideoInfoState>(
                    builder: (context, state) {
                      if (state is GetVideoInfoFailed) {
                        return Text(state.message);
                      }
                      if (state is GetVideoInfoLoading) {
                        return const CircularProgressIndicator();
                      }
                      if (state is GetVideoInfoLoaded) {
                        return AppPadding(
                          child: player,
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                  const SizedBox(height: 10),
                  BlocBuilder<MovieDetailBloc, MovieDetailState>(
                    builder: (context, state) {
                      if (state is MovieDetailLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is MovieDetailLoaded) {
                        if (state.movieDetail.isNotEmpty) {
                          final stateMovie = state.movieDetail.last;
                          final runtime = _getTimeString(stateMovie.runtime);
                          return Column(
                            children: <Widget>[
                              AppPadding(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Flexible(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Banner(
                                          message: '${stateMovie.voteAverage.round()}',
                                          location: BannerLocation.topEnd,
                                          child: Image.network(
                                            AppData.imagePath(
                                              posterPath: stateMovie.posterPath,
                                            ),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Column(
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                stateMovie.title,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      letterSpacing: 2,
                                                      height: 1.5,
                                                    ),
                                              ),
                                              const SizedBox(height: 20),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  CustomMovieTvDetailStatus(
                                                    icon: Icons.thumb_up_outlined,
                                                    title: NumberFormat.compact()
                                                        .format(stateMovie.popularity),
                                                  ),
                                                  CustomMovieTvDetailStatus(
                                                    icon: Icons.timelapse_outlined,
                                                    title: runtime,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              CustomMovieTvDetailStatus(
                                                icon: Icons.today,
                                                title: stateMovie.releaseDate.split('-').first,
                                              ),
                                              const SizedBox(height: 20),
                                              if (stateMovie.genres != null)
                                                Wrap(
                                                  spacing: 10,
                                                  runSpacing: 10,
                                                  children: List.generate(
                                                    stateMovie.genres.length,
                                                    (indexGenre) => GenreDescription(
                                                      title: stateMovie.genres[indexGenre].name,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 20),
                                          CustomElevatedButton(
                                            title: 'Reviews',
                                            onPressed: () => MovieReview.showMovieReview(
                                              context,
                                              type: DetailType.movie,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              AppPadding(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Text(
                                      'Movie Description',
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    const Divider(thickness: 2),
                                    BookDescription(stateMovie.overview),
                                    BlocBuilder<MovieSuggestionBloc, MovieSuggestionState>(
                                      builder: (context, state) {
                                        if (state is MovieSuggestionLoading) {
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        }
                                        if (state is MovieSuggestionFailed) {
                                          return Center(child: Text(state.message));
                                        }
                                        if (state is MovieSuggestionLoaded) {
                                          final listOfSuggestionMovies = <Widget>[];

                                          for (final element in state.movieSuggestion) {
                                            listOfSuggestionMovies.add(
                                              Container(
                                                margin: const EdgeInsets.symmetric(
                                                  vertical: 10,
                                                ),
                                                height: 150,
                                                child: GestureDetector(
                                                  onTap: () => GoRouter.of(context).pushNamed(
                                                    HomeDetailPage.routeName,
                                                    queryParams: {
                                                      'movie_id': element.id.toString(),
                                                    },
                                                  ),
                                                  child: BookItemCard(
                                                    description: element.overview,
                                                    isRRated: element.adult,
                                                    imgUrl: element.posterPath ??
                                                        element.backdropPath ??
                                                        '',
                                                    producer: element.voteAverage.toString(),
                                                    title: element.title,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    'Movie Suggestion',
                                                    style: Theme.of(context).textTheme.titleLarge,
                                                  ),
                                                ],
                                              ),
                                              const Divider(thickness: 2),
                                              if (state.movieSuggestion.isNotEmpty) ...[
                                                ListView.builder(
                                                  shrinkWrap: true,
                                                  physics: const NeverScrollableScrollPhysics(),
                                                  itemBuilder: (context, index) {
                                                    if (index >= state.movieSuggestion.length) {
                                                      return const BottomLoader();
                                                    } else {
                                                      return listOfSuggestionMovies[index];
                                                    }
                                                  },
                                                  itemCount: state.hasReachLimit
                                                      ? listOfSuggestionMovies.length
                                                      : listOfSuggestionMovies.length + 1,
                                                ),
                                                if (state.status == PaginateStatus.empty)
                                                  AppPadding(
                                                    bottom: 20,
                                                    child: Text(
                                                      'No more suggestion',
                                                      style: Theme.of(context).textTheme.titleLarge,
                                                    ),
                                                  ),
                                              ] else
                                                Center(
                                                  child: Text(
                                                    'No Movie Suggestion',
                                                    style: Theme.of(context).textTheme.labelMedium,
                                                  ),
                                                )
                                            ],
                                          );
                                        }
                                        return const Center(
                                          child: Text(AppData.somethingWentWrong),
                                        );
                                      },
                                    )
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                      }
                      if (state is MovieDetailFailed) {
                        return Center(
                          child: Text(state.message),
                        );
                      }
                      return const Center(
                        child: Text('Something Went Wrong'),
                      );
                    },
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GenreDescription extends StatelessWidget {
  const GenreDescription({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(),
      ),
    );
  }
}
