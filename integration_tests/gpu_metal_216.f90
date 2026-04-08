program gpu_metal_216
  implicit none
  type :: inner_t
    real, allocatable :: x(:)
  end type
  type :: outer_t
    type(inner_t) :: inner
  end type
  integer :: i
  type(outer_t) :: arr(2)
  real :: r(2)
  arr(1) = outer_t(inner_t([1.0]))
  arr(2) = outer_t(inner_t([2.0]))
  r = 0.0
  do concurrent(i = 1:2)
    r(i) = arr(i)%inner%x(1)
  end do
  if (abs(r(1) - 1.0) > 1e-6 .or. abs(r(2) - 2.0) > 1e-6) error stop
  print *, r(1), r(2)
end program
