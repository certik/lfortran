program gpu_metal_231
  implicit none

  type :: a_t
    real, allocatable :: v(:)
  end type

  type :: b_t
    type(a_t) :: x
  end type

  type :: c_t
    type(b_t) :: y
  end type

  type(b_t) :: src(2)
  type(c_t), allocatable :: dst(:)
  integer :: i

  do i = 1, 2
    src(i) = b_t(a_t([real :: i]))
  end do

  allocate(dst(2))
  do concurrent(i = 1:2)
    dst(i) = c_t(src(i))
  end do

  if (dst(1)%y%x%v(1) /= 1.0) error stop
  if (dst(2)%y%x%v(1) /= 2.0) error stop
  print *, "ok"
end program
