program submodule_24a
  use submodule_24_mod
  implicit none
  type(string_t) :: s
  s = string_t("hello")
  if (s%get_val() /= "hello") error stop
  print *, "ok"
end program
