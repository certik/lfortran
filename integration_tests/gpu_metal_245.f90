! Test: array constructor with pure function returning nested derived type
! with allocatable component inside do concurrent (GPU offloading).
program gpu_metal_245
  implicit none
  type :: dt
    real, allocatable :: v(:)
  end type
  type :: wrapper
    type(dt) :: item
  end type

  type(wrapper), allocatable :: arr(:)
  type(dt), allocatable :: src(:)
  integer :: i, n
  n = 4
  allocate(src(n))
  do i = 1, n
    src(i) = dt([real(i)])
  end do
  allocate(arr(n))
  do concurrent(i=1:n)
    arr(i:i) = [wrap(src(i))]
  end do
  if (abs(arr(1)%item%v(1) - 1.0) > 1e-6) error stop
  if (abs(arr(2)%item%v(1) - 2.0) > 1e-6) error stop
  if (abs(arr(3)%item%v(1) - 3.0) > 1e-6) error stop
  if (abs(arr(4)%item%v(1) - 4.0) > 1e-6) error stop
  print *, "ok"
contains
  pure function wrap(x) result(w)
    type(dt), intent(in) :: x
    type(wrapper) :: w
    w%item = x
  end function
end program
