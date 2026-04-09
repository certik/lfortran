module gpu_metal_244_m
  implicit none

  type :: inner_t
    integer :: v
  end type

  type :: outer_t
    type(inner_t), allocatable :: items(:)
  end type

contains

  pure function wrap(items) result(res)
    type(inner_t), intent(in) :: items(:)
    type(outer_t) :: res
    res%items = items
  end function

end module

program gpu_metal_244
  use gpu_metal_244_m
  implicit none

  integer, parameter :: n = 2
  type(inner_t) :: arr(1, n)
  type(outer_t) :: results(n)
  integer :: i

  do i = 1, n
    arr(1, i) = inner_t(v=i*10)
  end do

  do concurrent(i = 1:n)
    results(i) = wrap(arr(:,i))
  end do

  if (results(1)%items(1)%v /= 10) error stop
  if (results(2)%items(1)%v /= 20) error stop
  print *, "ok"
end program
