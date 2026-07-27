const imageCache = new Map<string, HTMLImageElement>();
const decodeCache = new Map<string, Promise<void>>();

export function preloadImage(src: string): Promise<void> {
  const cached = decodeCache.get(src);
  if (cached) return cached;

  const image = new Image();
  image.decoding = "async";
  image.src = src;
  imageCache.set(src, image);

  const decoded =
    typeof image.decode === "function"
      ? image.decode().catch(() => undefined)
      : new Promise<void>((resolve) => {
          image.onload = () => resolve();
          image.onerror = () => resolve();
        });

  decodeCache.set(src, decoded);
  return decoded;
}

function scheduleIdle(callback: () => void): number {
  if (typeof window.requestIdleCallback === "function") {
    return window.requestIdleCallback(callback, { timeout: 1500 });
  }
  return window.setTimeout(callback, 50);
}

function cancelIdle(handle: number): void {
  if (typeof window.cancelIdleCallback === "function") {
    window.cancelIdleCallback(handle);
    return;
  }
  window.clearTimeout(handle);
}

export function preloadImagesWhenIdle(sources: Iterable<string>): () => void {
  const queue = [...new Set(sources)];
  let cancelled = false;
  let idleHandle: number | null = null;

  const preloadNext = () => {
    if (cancelled || queue.length === 0) return;
    idleHandle = scheduleIdle(() => {
      idleHandle = null;
      const src = queue.shift();
      if (!src) return;
      void preloadImage(src).finally(preloadNext);
    });
  };

  preloadNext();

  return () => {
    cancelled = true;
    if (idleHandle !== null) cancelIdle(idleHandle);
  };
}
