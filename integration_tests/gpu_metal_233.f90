module gpu_metal_233_m
  implicit none
  type :: container_t
    real, allocatable :: items(:)
  end type
contains
  elemental function double_it(a) result(r)
    real, intent(in) :: a
    real :: r
    r = a * 2.0
  end function
  pure function new_container(items) result(c)
    real, intent(in) :: items(:)
    type(container_t) :: c
    c%items = items
  end function
end module

program gpu_metal_233
  use gpu_metal_233_m
  implicit none
  integer, parameter :: n = 3
  real :: x(2, n)
  type(container_t) :: res(n)
  integer :: i

  do i = 1, n
    x(:, i) = [real(i), real(i + 10)]
  end do

  do concurrent(i = 1:n)
    res(i) = new_container(double_it(x(:, i)))
  end do

  do i = 1, n
    if (.not. allocated(res(i)%items)) error stop
    if (size(res(i)%items) /= 2) error stop
  end do
  if (res(1)%items(1) /= 2.0) error stop
  if (res(1)%items(2) /= 22.0) error stop
  if (res(2)%items(1) /= 4.0) error stop
  if (res(2)%items(2) /= 24.0) error stop
  if (res(3)%items(1) /= 6.0) error stop
  if (res(3)%items(2) /= 26.0) error stop
  print *, "OK"
end program
