module separate_compilation_41_m
  implicit none

  integer, parameter :: rk = kind(1.0)

  type t(k)
    integer, kind :: k = rk
    real(k) :: a
    type(t(k)), allocatable :: next
  end type t

  interface
    module function f(x) result(n)
      type(t), intent(in) :: x
      integer :: n
    end function f
  end interface
end module separate_compilation_41_m

submodule(separate_compilation_41_m) separate_compilation_41_s
  implicit none
contains
  module procedure f
    if (allocated(x%next)) then
      n = 1
    else
      n = 0
    end if
  end procedure f
end submodule separate_compilation_41_s

program separate_compilation_41
  use separate_compilation_41_m, only: t, f
  implicit none

  type(t) :: x

  if (f(x) /= 0) error stop 1
end program separate_compilation_41
