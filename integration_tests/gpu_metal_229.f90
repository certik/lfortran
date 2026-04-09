program gpu_metal_229
  implicit none

  type :: inner_t
    real, allocatable :: v(:)
  end type

  type :: outer_t
    type(inner_t), allocatable :: items(:)
  end type

  integer, parameter :: n = 4
  integer :: i
  type(inner_t) :: src(n)
  type(outer_t) :: dst(n)

  do i = 1, n
    src(i) = inner_t([real :: i, i+1])
  end do

  do concurrent(i=1:n)
    dst(i)%items = [src(i)]
  end do

  do i = 1, n
    if (.not. allocated(dst(i)%items)) error stop
    if (.not. allocated(dst(i)%items(1)%v)) error stop
    if (size(dst(i)%items(1)%v) /= 2) error stop
    if (nint(dst(i)%items(1)%v(1)) /= i) error stop
    if (nint(dst(i)%items(1)%v(2)) /= i + 1) error stop
  end do
  print *, "ok"

end program
