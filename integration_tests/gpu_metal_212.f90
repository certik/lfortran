module gpu_metal_212_mod
  implicit none
  type :: t
    real, allocatable :: v(:)
  end type
  interface t
    module procedure construct_t
  end interface
contains
  pure function construct_t(vals) result(res)
    real, intent(in) :: vals(:)
    type(t) :: res
    res%v = vals
  end function
end module

program gpu_metal_212
  use gpu_metal_212_mod
  implicit none
  integer, parameter :: n = 3
  type(t), allocatable :: a(:)
  real :: src(n)
  integer :: i
  src = [10.0, 20.0, 30.0]
  allocate(a(n))
  do concurrent(i = 1:n)
    a(i) = t([src(i)])
  end do
  if (a(1)%v(1) /= 10.0) error stop
  if (a(2)%v(1) /= 20.0) error stop
  if (a(3)%v(1) /= 30.0) error stop
  print *, "PASS"
end program
