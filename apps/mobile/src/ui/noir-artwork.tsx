import { View } from 'react-native';

const ribbons = [
  { top: 12, right: -62, color: '#54427F' },
  { top: 44, right: -42, color: '#7461AF' },
  { top: 76, right: -22, color: '#A18DD9' },
] as const;

export function NoirArtwork() {
  return <View pointerEvents="none" accessible={false} accessibilityElementsHidden importantForAccessibility="no-hide-descendants"
    style={{ position: 'absolute', top: 0, right: 0, width: 126, height: 152, overflow: 'hidden' }}>
    {ribbons.map(({ top, right, color }) => <View key={color} style={{
      position: 'absolute', top, right, width: 140, height: 38,
      borderRadius: 19, backgroundColor: color, opacity: 0.4,
      transform: [{ rotate: '-38deg' }],
    }} />)}
  </View>;
}
