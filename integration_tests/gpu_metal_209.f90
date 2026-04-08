program gpu_metal_209
  implicit none

  type :: t_t
    real, allocatable :: v(:)
  end type

  type(t_t), allocatable :: arr(:)
  integer :: i

  allocate(arr(4))

  do concurrent(i=1:4)
    arr(i) = f(i)
  end do

  if (.not. allocated(arr(1)%v)) error stop "arr(1)%v not allocated"
  if (size(arr(1)%v) /= 1) error stop "arr(1)%v wrong size"
  if (abs(arr(1)%v(1) - 1.0) > 0.01) error stop "wrong value at arr(1)"
  if (abs(arr(2)%v(1) - 2.0) > 0.01) error stop "wrong value at arr(2)"
  if (abs(arr(3)%v(1) - 3.0) > 0.01) error stop "wrong value at arr(3)"
  if (abs(arr(4)%v(1) - 4.0) > 0.01) error stop "wrong value at arr(4)"
  print *, "PASSED"

contains

  pure function f(x) result(t)
    integer, intent(in) :: x
    type(t_t) t
    t%v = [real(x)]
  end function

end program
