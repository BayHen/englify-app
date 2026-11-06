import { Component, type PropsWithChildren } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

type State = { failed: boolean };

export class AppErrorBoundary extends Component<PropsWithChildren, State> {
  state: State = { failed: false };

  static getDerivedStateFromError(): State {
    return { failed: true };
  }

  render() {
    if (!this.state.failed) return this.props.children;
    return (
      <View style={styles.container}>
        <Text style={styles.title}>Something went wrong</Text>
        <Text style={styles.detail}>Please try opening this screen again.</Text>
        <Pressable accessibilityRole="button" onPress={() => this.setState({ failed: false })} style={styles.button}>
          <Text style={styles.buttonText}>Try again</Text>
        </Pressable>
      </View>
    );
  }
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 32, backgroundColor: '#F7F5FF' },
  title: { fontSize: 24, fontWeight: '700', color: '#211B3A' },
  detail: { fontSize: 16, color: '#655D80', marginTop: 8, marginBottom: 20 },
  button: { backgroundColor: '#7456F1', padding: 14, borderRadius: 14, alignItems: 'center' },
  buttonText: { color: '#FFFFFF', fontWeight: '700' },
});
