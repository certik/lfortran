program gpu_metal_225
  implicit none

  type :: wrapper_t
    real, allocatable :: x(:)
  end type

  type(wrapper_t) :: arr(2)
  real :: vals(2, 2)
  integer :: i

  vals(:, 1) = [1.0, 2.0]
  vals(:, 2) = [3.0, 4.0]

  do concurrent(i = 1:2)
    arr(i) = wrapper_t(vals(:, i))
  end do

  do i = 1, 2
    if (size(arr(i)%x) /= 2) error stop
  end do
  if (abs(arr(1)%x(1) - 1.0) > 1e-6) error stop
  if (abs(arr(1)%x(2) - 2.0) > 1e-6) error stop
  if (abs(arr(2)%x(1) - 3.0) > 1e-6) error stop
  if (abs(arr(2)%x(2) - 4.0) > 1e-6) error stop
  print *, "ok"
end program
