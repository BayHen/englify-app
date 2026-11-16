import { Component, type PropsWithChildren } from 'react';
import { StyleSheet, View } from 'react-native';
import { AppButton, AppText } from '@/ui';

type State = { failed: boolean };

function ErrorFallback({ onRetry }: { onRetry: () => void }) {
  return <View style={styles.container}>
    <AppText variant="title">Something went wrong</AppText>
    <AppText tone="muted" style={styles.detail}>Please try opening this screen again.</AppText>
    <AppButton label="Try again" onPress={onRetry} />
  </View>;
}

export class AppErrorBoundary extends Component<PropsWithChildren, State> {
  state: State = { failed: false };

  static getDerivedStateFromError(): State {
    return { failed: true };
  }

  render() {
    if (!this.state.failed) return this.props.children;
    return <ErrorFallback onRetry={() => this.setState({ failed: false })} />;
  }
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 32, backgroundColor: '#F7F5FF' },
  detail: { fontSize: 16, color: '#655D80', marginTop: 8, marginBottom: 20 },
});
