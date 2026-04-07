! Test: nested function calls returning derived type with allocatable
! component inside do concurrent. Verifies Metal codegen declares
! __size_ variables for temporary struct locals and emits correct
! address-space overloads for functions with Out struct parameters.
program gpu_metal_200
  implicit none

  type :: dt_t
    real, allocatable :: vals(:)
  end type

  type(dt_t) :: res(4)
  real :: x(4)
  integer :: i

  x = [1.0, 2.0, 3.0, 4.0]

  do concurrent(i=1:4)
    res(i) = outer(inner(x(i)))
  end do

  if (abs(res(1)%vals(1) - 1.0) > 1e-6) error stop
  if (abs(res(2)%vals(1) - 2.0) > 1e-6) error stop
  if (abs(res(3)%vals(1) - 3.0) > 1e-6) error stop
  if (abs(res(4)%vals(1) - 4.0) > 1e-6) error stop
  print *, "PASS"

contains

  pure function inner(a) result(obj)
    real, intent(in) :: a
    type(dt_t) :: obj
    obj%vals = [a]
  end function

  pure function outer(d) result(obj)
    type(dt_t), intent(in) :: d
    type(dt_t) :: obj
    obj = d
  end function

end program
