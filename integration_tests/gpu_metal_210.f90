module gpu_metal_210_mod
  implicit none
  type :: mytype
    real, allocatable :: vals(:)
  end type
  interface mytype
    module procedure construct
  end interface
contains
  pure function construct(v) result(t)
    real, intent(in) :: v(:)
    type(mytype) :: t
    t%vals = v
  end function
end module

program gpu_metal_210
  use gpu_metal_210_mod
  implicit none
  type(mytype), allocatable :: arr(:)
  real :: data(2, 3)
  integer :: i

  data = reshape([1.,2.,3.,4.,5.,6.], [2,3])

  allocate(arr(3))
  do concurrent(i=1:3)
    arr(i) = mytype(data(:,i))
  end do

  if (arr(1)%vals(1) /= 1.0) error stop
  if (arr(1)%vals(2) /= 2.0) error stop
  if (arr(2)%vals(1) /= 3.0) error stop
  if (arr(2)%vals(2) /= 4.0) error stop
  if (arr(3)%vals(1) /= 5.0) error stop
  if (arr(3)%vals(2) /= 6.0) error stop
  print *, "PASS"
end program
