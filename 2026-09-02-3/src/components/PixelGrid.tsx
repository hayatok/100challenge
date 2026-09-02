type Props = {
  pixels: Float32Array
  highlighted?: Set<number>
  label: string
}

export function PixelGrid({ pixels, highlighted = new Set(), label }: Props) {
  return (
    <div className="pixel-grid" role="img" aria-label={label} data-testid="pixel-grid">
      {Array.from(pixels, (value, index) => (
        <span
          key={index}
          aria-hidden="true"
          className={highlighted.has(index) ? 'pixel pixel--highlighted' : 'pixel'}
          style={{ '--pixel': value } as React.CSSProperties}
          title={`行${Math.floor(index / 28) + 1} 列${index % 28 + 1}: ${value.toFixed(3)}`}
        />
      ))}
    </div>
  )
}
