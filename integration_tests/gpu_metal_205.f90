module gpu_metal_205_m
  implicit none
  type :: t
    real, allocatable :: v(:)
  end type
  interface
    pure module function get_v(self) result(r)
      type(t), intent(in) :: self
      real, allocatable :: r(:)
    end function
  end interface
end module

submodule(gpu_metal_205_m) gpu_metal_205_s
  implicit none
contains
  module procedure get_v
    r = self%v
  end procedure
end submodule

program gpu_metal_205
  use gpu_metal_205_m
  implicit none
  integer, parameter :: n = 4
  type(t) :: arr(n)
  real :: results(n)
  integer :: i

  do i = 1, n
    arr(i)%v = [real(i), real(i+1)]
  end do

  do concurrent(i=1:n)
    results(i) = f(arr(i))
  end do

  do i = 1, n
    if (abs(results(i) - real(2*i + 1)) > 1e-6) error stop
  end do
  print *, "PASS"

contains
  pure function f(x) result(r)
    type(t), intent(in) :: x
    real :: r
    associate(s => sum(get_v(x)))
      r = s
    end associate
  end function
end program
