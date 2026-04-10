program gpu_metal_260
implicit none
real :: x(2, 2), r(2)
x(:,1) = [1.0, 2.0]
x(:,2) = [3.0, 4.0]
call compute(x, r, 2)
print *, r(1), r(2)
if (abs(r(1) - 3.0) > 0.01) error stop
if (abs(r(2) - 7.0) > 0.01) error stop
contains
subroutine compute(x, r, n)
  real, intent(in) :: x(:,:)
  real, intent(out) :: r(:)
  integer, intent(in) :: n
  integer :: i
  do concurrent(i = 1:n)
    block
      real :: tmp(size(x, 1))
      tmp = x(:, i)
      r(i) = sum(tmp)
    end block
  end do
end subroutine
end program
