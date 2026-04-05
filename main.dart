import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

void main() {
  runApp(MyApp());
}

//////////////////////////////////////////////////////////
// DOMAIN LAYER
//////////////////////////////////////////////////////////

class Post {
  final int id;
  final String title;
  final String body;

  Post({
    required this.id,
    required this.title,
    required this.body,
  });
}

abstract class PostRepository {
  Future<List<Post>> getPosts();
}

class GetPosts {
  final PostRepository repository;

  GetPosts(this.repository);

  Future<List<Post>> call() async {
    return await repository.getPosts();
  }
}

//////////////////////////////////////////////////////////
// DATA LAYER
//////////////////////////////////////////////////////////

class PostModel extends Post {
  PostModel({
    required int id,
    required String title,
    required String body,
  }) : super(id: id, title: title, body: body);

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'],
      title: json['title'],
      body: json['body'],
    );
  }
}

abstract class PostRemoteDataSource {
  Future<List<PostModel>> fetchPosts();
}

class PostRemoteDataSourceImpl implements PostRemoteDataSource {
  final Dio dio;

  PostRemoteDataSourceImpl(this.dio);

  @override
  Future<List<PostModel>> fetchPosts() async {
    final response = await dio.get(
      'https://jsonplaceholder.typicode.com/posts',
    );

    return (response.data as List)
        .map((e) => PostModel.fromJson(e))
        .toList();
  }
}

class PostRepositoryImpl implements PostRepository {
  final PostRemoteDataSource remoteDataSource;

  PostRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<Post>> getPosts() async {
    return await remoteDataSource.fetchPosts();
  }
}

//////////////////////////////////////////////////////////
// PRESENTATION LAYER (BLOC)
//////////////////////////////////////////////////////////

abstract class PostEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class FetchPosts extends PostEvent {}

class RefreshPosts extends PostEvent {}

abstract class PostState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PostInitial extends PostState {}

class PostLoading extends PostState {}

class PostLoaded extends PostState {
  final List<Post> posts;

  PostLoaded(this.posts);

  @override
  List<Object?> get props => [posts];
}

class PostError extends PostState {
  final String message;

  PostError(this.message);

  @override
  List<Object?> get props => [message];
}

class PostBloc extends Bloc<PostEvent, PostState> {
  final GetPosts getPosts;

  PostBloc(this.getPosts) : super(PostInitial()) {
    on<FetchPosts>(_onFetchPosts);
    on<RefreshPosts>(_onRefreshPosts);
  }

  Future<void> _onFetchPosts(
      FetchPosts event, Emitter<PostState> emit) async {
    emit(PostLoading());

    try {
      final posts = await getPosts();
      emit(PostLoaded(posts));
    } catch (e) {
      emit(PostError('Ошибка загрузки'));
    }
  }

  Future<void> _onRefreshPosts(
      RefreshPosts event, Emitter<PostState> emit) async {
    try {
      final posts = await getPosts();
      emit(PostLoaded(posts));
    } catch (e) {
      emit(PostError('Ошибка обновления'));
    }
  }
}

//////////////////////////////////////////////////////////
// UI
//////////////////////////////////////////////////////////

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dio = Dio();
    final dataSource = PostRemoteDataSourceImpl(dio);
    final repository = PostRepositoryImpl(dataSource);
    final getPosts = GetPosts(repository);

    return MaterialApp(
      home: BlocProvider(
        create: (_) => PostBloc(getPosts)..add(FetchPosts()),
        child: HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Posts')),
      body: BlocBuilder<PostBloc, PostState>(
        builder: (context, state) {
          if (state is PostLoading) {
            return Center(child: CircularProgressIndicator());
          } else if (state is PostLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<PostBloc>().add(RefreshPosts());
              },
              child: ListView.builder(
                itemCount: state.posts.length,
                itemBuilder: (context, index) {
                  final post = state.posts[index];
                  return ListTile(
                    title: Text(post.title),
                    subtitle: Text(post.body),
                  );
                },
              ),
            );
          } else if (state is PostError) {
            return Center(child: Text(state.message));
          }

          return SizedBox();
        },
      ),
    );
  }
}
