program gpu_metal_203
  implicit none

  type :: item_t
    real :: v
  end type

  integer, parameter :: n = 4
  real, allocatable :: xs(:,:)
  real :: res(n)
  integer :: i

  allocate(xs(n, n))
  do i = 1, n
    xs(:, i) = real(i)
  end do

  do concurrent(i = 1:n)
    res(i) = sum_items(make_item(xs(:,i)))
  end do

  ! Verify: res(i) == sum of xs(:,i) = n * real(i)
  do i = 1, n
    if (abs(res(i) - real(n * i)) > 1e-6) error stop
  end do
  print *, "ok"

contains

  elemental function make_item(x) result(it)
    real, intent(in) :: x
    type(item_t) :: it
    it%v = x
  end function

  pure function sum_items(items) result(s)
    type(item_t), intent(in) :: items(:)
    real :: s
    integer :: j
    s = 0.0
    do j = 1, size(items)
      s = s + items(j)%v
    end do
  end function

end program
