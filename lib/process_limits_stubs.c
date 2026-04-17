#include <caml/alloc.h>
#include <caml/fail.h>
#include <caml/mlvalues.h>

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/resource.h>

static void fail_with_errno(const char *prefix)
{
  char buffer[256];
  snprintf(buffer, sizeof(buffer), "%s: %s", prefix, strerror(errno));
  caml_failwith(buffer);
}

CAMLprim value caml_process_limits_get_address_space_limit(value unit_value)
{
  (void)unit_value;
  struct rlimit limit;
  if (getrlimit(RLIMIT_AS, &limit) != 0) {
    fail_with_errno("getrlimit(RLIMIT_AS)");
  }
  if (limit.rlim_cur == RLIM_INFINITY || limit.rlim_cur > INT64_MAX) {
    return caml_copy_int64(-1);
  }
  return caml_copy_int64((int64_t)limit.rlim_cur);
}

CAMLprim value caml_process_limits_set_address_space_limit(value bytes_value)
{
  int64_t bytes = Int64_val(bytes_value);
  struct rlimit current;
  struct rlimit updated;

  if (bytes <= 0) {
    caml_failwith("La limite mémoire doit être strictement positive.");
  }

  if (getrlimit(RLIMIT_AS, &current) != 0) {
    fail_with_errno("getrlimit(RLIMIT_AS)");
  }

  updated = current;
  updated.rlim_cur = (rlim_t)bytes;
  if (current.rlim_max != RLIM_INFINITY && updated.rlim_cur > current.rlim_max) {
    caml_failwith("La limite mémoire demandée dépasse la limite maximale autorisée.");
  }

  if (setrlimit(RLIMIT_AS, &updated) != 0) {
    fail_with_errno("setrlimit(RLIMIT_AS)");
  }

  return Val_unit;
}
