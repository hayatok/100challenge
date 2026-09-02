import { forwardRef, useEffect, useImperativeHandle, useRef } from 'react'

export type DrawingPadHandle = {
  clear: () => void
  canvas: () => HTMLCanvasElement | null
}

type Props = {
  onStrokeEnd: () => void
}

export const DrawingPad = forwardRef<DrawingPadHandle, Props>(function DrawingPad({ onStrokeEnd }, ref) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const drawing = useRef(false)

  const clear = () => {
    const canvas = canvasRef.current
    const context = canvas?.getContext('2d')
    if (!canvas || !context) return
    context.fillStyle = '#ffffff'
    context.fillRect(0, 0, canvas.width, canvas.height)
  }

  useEffect(clear, [])
  useImperativeHandle(ref, () => ({ clear, canvas: () => canvasRef.current }))

  const position = (event: React.PointerEvent<HTMLCanvasElement>) => {
    const canvas = event.currentTarget
    const bounds = canvas.getBoundingClientRect()
    return {
      x: (event.clientX - bounds.left) * canvas.width / bounds.width,
      y: (event.clientY - bounds.top) * canvas.height / bounds.height,
    }
  }

  const start = (event: React.PointerEvent<HTMLCanvasElement>) => {
    const canvas = event.currentTarget
    const context = canvas.getContext('2d')
    if (!context) return
    drawing.current = true
    canvas.setPointerCapture(event.pointerId)
    const point = position(event)
    context.beginPath()
    context.moveTo(point.x, point.y)
    context.lineWidth = 22
    context.lineCap = 'round'
    context.lineJoin = 'round'
    context.strokeStyle = '#182126'
  }

  const move = (event: React.PointerEvent<HTMLCanvasElement>) => {
    if (!drawing.current) return
    const context = event.currentTarget.getContext('2d')
    if (!context) return
    const point = position(event)
    context.lineTo(point.x, point.y)
    context.stroke()
  }

  const end = (event: React.PointerEvent<HTMLCanvasElement>) => {
    if (!drawing.current) return
    drawing.current = false
    event.currentTarget.releasePointerCapture(event.pointerId)
    onStrokeEnd()
  }

  return (
    <canvas
      ref={canvasRef}
      width="280"
      height="280"
      className="drawing-pad"
      aria-label="手書き数字の入力欄"
      onPointerDown={start}
      onPointerMove={move}
      onPointerUp={end}
      onPointerCancel={end}
    />
  )
})
