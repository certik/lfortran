program gpu_metal_230
  ! Test do concurrent with struct constructor where a non-allocatable
  ! struct member contains an allocatable sub-member.
  ! outer_t%x is a non-allocatable inner_t, but inner_t%v is allocatable.
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
    src(i) = inner_t(v=[real :: i, i * 10])
  end do

  do concurrent(i = 1:n)
    dst(i) = outer_t(x=src(i))
  end do

  do i = 1, n
    if (.not. allocated(dst(i)%x%v)) error stop
    if (size(dst(i)%x%v) /= 2) error stop
    if (nint(dst(i)%x%v(1)) /= i) error stop
    if (nint(dst(i)%x%v(2)) /= i * 10) error stop
  end do
  print *, "ok"

end program
