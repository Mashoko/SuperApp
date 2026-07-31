/// Returns the balance value a fetch attempt should result in.
///
/// On success (`ok == true`), the newly-fetched value replaces the
/// previous one. On failure (`ok == false`), the previous value is
/// returned unchanged — a failed refresh must never clear an
/// already-displayed balance.
T resolveOnFetch<T>({required T previous, required bool ok, required T onSuccess}) {
  return ok ? onSuccess : previous;
}
