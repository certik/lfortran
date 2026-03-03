module pdt_14_mod
  implicit none
  type :: foo_t(k)
    integer, kind :: k = kind(1.)
    real(k) :: x = real(1.5, k)
  end type
end module

program pdt_14
  use pdt_14_mod
  implicit none
  type(foo_t) :: a
  print *, a%x
  if (abs(a%x - 1.5) > 1e-6) error stop
end program
