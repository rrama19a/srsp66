import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
              create: (context) => AuthenticationBloc(UserRepository())),
          BlocProvider(
              create: (context) =>
                  UserSettingsBloc(SharedPreferences.getInstance())),
        ],
        child: AuthenticationPage(),
      ),
    );
  }
}

class AuthenticationPage extends StatefulWidget {
  @override
  _AuthenticationPageState createState() => _AuthenticationPageState();
}

class _AuthenticationPageState extends State<AuthenticationPage> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authentication')),
      body: Center(
        child: BlocBuilder<AuthenticationBloc, AuthenticationState>(
          builder: (context, state) {
            if (state is AuthenticationAuthenticated) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Logged In!'),
                  Text('Email: ${state.email}'), // Display the email
                  Text('Password: ${state.password}'), // Display the password
                  ElevatedButton(
                    onPressed: () =>
                        context.read<AuthenticationBloc>().add(LoggedOut()),
                    child: const Text('Sign Out'),
                  ),
                ],
              );
            }

            return Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      if (value == null || !value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                    onSaved: (value) => _email = value ?? '',
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) {
                      if (value != '12345') {
                        return 'Incorrect password';
                      }
                      return null;
                    },
                    onSaved: (value) => _password = value ?? '',
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        _formKey.currentState?.save();
                        context
                            .read<AuthenticationBloc>()
                            .add(LoggedIn(_email, _password));
                      }
                    },
                    child: const Text('Log In'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

abstract class AuthenticationState {}

class AuthenticationUnauthenticated extends AuthenticationState {}

class AuthenticationAuthenticated extends AuthenticationState {
  final String email;
  final String password;

  AuthenticationAuthenticated(this.email, this.password);
}

abstract class AuthenticationEvent {}

class LoggedIn extends AuthenticationEvent {
  final String email;
  final String password;

  LoggedIn(this.email, this.password);
}

class LoggedOut extends AuthenticationEvent {}

class AuthenticationBloc
    extends Bloc<AuthenticationEvent, AuthenticationState> {
  final UserRepository userRepository;

  AuthenticationBloc(this.userRepository)
      : super(AuthenticationUnauthenticated()) {
    on<LoggedIn>((event, emit) async {
      final isAuthenticated =
          await userRepository.authenticate(event.email, event.password);
      if (isAuthenticated) {
        emit(AuthenticationAuthenticated(event.email, event.password));
      } else {
        emit(AuthenticationUnauthenticated());
      }
    });

    on<LoggedOut>((event, emit) async {
      await userRepository.signOut();
      emit(AuthenticationUnauthenticated());
    });
  }
}

class UserRepository {
  Future<bool> authenticate(String email, String password) async {
    if (email.contains('@') && password == '12345') {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAuthenticated', true);
      return true;
    }
    return false;
  }

  Future<void> signOut() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAuthenticated', false);
  }
}

class UserSettingsBloc extends Bloc<UserSettingsEvent, UserSettingsState> {
  final Future<SharedPreferences> prefsFuture;

  UserSettingsBloc(this.prefsFuture) : super(SettingsLoading()) {
    on<LoadSettings>((event, emit) async {
      try {
        final prefs = await prefsFuture;
        var settings = {
          'theme': prefs.getString('theme') ?? 'light',
          'language': prefs.getString('language') ?? 'English',
        };
        emit(SettingsLoaded(settings));
      } catch (e) {
        emit(SettingsError());
      }
    });

    on<UpdateSettings>((event, emit) async {
      try {
        final prefs = await prefsFuture;
        await prefs.setString('theme', event.settings['theme']);
        await prefs.setString('language', event.settings['language']);
        emit(SettingsLoaded(event.settings));
      } catch (e) {
        emit(SettingsError());
      }
    });
  }
}

abstract class UserSettingsEvent {}

class LoadSettings extends UserSettingsEvent {}

class UpdateSettings extends UserSettingsEvent {
  final Map<String, dynamic> settings;
  UpdateSettings(this.settings);
}

abstract class UserSettingsState {}

class SettingsLoading extends UserSettingsState {}

class SettingsLoaded extends UserSettingsState {
  final Map<String, dynamic> settings;
  SettingsLoaded(this.settings);
}

class SettingsError extends UserSettingsState {}
