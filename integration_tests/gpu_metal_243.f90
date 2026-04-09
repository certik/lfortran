program gpu_metal_243
  ! Test do concurrent with a pure function that returns a nested
  ! derived type (outer_t) whose non-allocatable member (x) is a
  ! struct (inner_t) with an allocatable array component (v).
  ! This exercises Metal GPU offloading of function-call results
  ! with nested allocatable sub-members.
  implicit none

  type :: inner_t
    real, allocatable :: v(:)
  end type

  type :: outer_t
    type(inner_t) :: x
  end type

  integer, parameter :: n = 4
  type(inner_t) :: src(n)
  type(outer_t) :: dst(n)
  integer :: i

  do i = 1, n
    src(i) = inner_t(v=[real :: i, 2*i])
  end do

  do concurrent (i = 1:n)
    dst(i) = wrap(src(i))
  end do

  do i = 1, n
    if (.not. allocated(dst(i)%x%v)) error stop
    if (size(dst(i)%x%v) /= 2) error stop
    if (nint(dst(i)%x%v(1)) /= i) error stop
    if (nint(dst(i)%x%v(2)) /= 2*i) error stop
  end do
  print *, "ok"

contains

  pure function wrap(a) result(w)
    type(inner_t), intent(in) :: a
    type(outer_t) :: w
    w%x = a
  end function

end program
