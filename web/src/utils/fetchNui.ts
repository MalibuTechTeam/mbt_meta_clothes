/**
 * Wrapper for NUI Callbacks to Lua
 */

declare global {
  interface Window {
    GetParentResourceName?: () => string;
    invokeNative?: unknown;
  }
}

export async function fetchNui<T = unknown>(eventName: string, data: Record<string, unknown> = {}): Promise<T | false> {
  const options: RequestInit = {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: JSON.stringify(data),
  };

  const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'mbt_meta_clothes';

  try {
    const resp = await fetch(`https://${resourceName}/${eventName}`, options);
    return await resp.json() as T;
  } catch {
    return false;
  }
}
