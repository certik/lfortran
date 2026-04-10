! Test nested derived types with allocatable components through
! non-allocatable struct intermediaries inside do concurrent.
! Verifies that deeply nested allocatable data (inner_t.v) is
! correctly copied when a pure function assigns to the outer struct.
program gpu_metal_250
  implicit none
  type :: inner_t
    real, allocatable :: v(:)
  end type
  type :: mid_t
    type(inner_t) :: a
  end type
  type :: outer_t
    type(mid_t), allocatable :: items(:)
  end type
  integer :: i
  type(inner_t) :: x(2)
  type(outer_t) :: r(2)

  x(1) = inner_t([1.0, 2.0])
  x(2) = inner_t([3.0, 4.0])

  do concurrent(i = 1:2)
    r(i) = make_outer([mid_t(x(i))])
  end do

  do i = 1, 2
    if (size(r(i)%items) /= 1) error stop
    if (size(r(i)%items(1)%a%v) /= 2) error stop
  end do
  if (r(1)%items(1)%a%v(1) /= 1.0) error stop
  if (r(1)%items(1)%a%v(2) /= 2.0) error stop
  if (r(2)%items(1)%a%v(1) /= 3.0) error stop
  if (r(2)%items(1)%a%v(2) /= 4.0) error stop
  print *, "PASS"
contains
  pure function make_outer(items) result(o)
    type(mid_t), intent(in) :: items(:)
    type(outer_t) :: o
    o%items = items
  end function
end program
